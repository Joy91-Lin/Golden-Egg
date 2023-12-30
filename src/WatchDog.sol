pragma solidity ^0.8.21;

import "./BirthFactory.sol";
import "chainlink/vrf/VRFV2WrapperConsumerBase.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./ChickenCoop.sol";
import "./Token.sol";

interface IAttckGameEvent{
    event AttackRequest(uint256 indexed requestId, address indexed requester, address indexed target);
    event AttackResult(uint256 indexed requestId, address indexed requester, address indexed target, bool result);
}

contract WatchDog is BirthFactory, VRFV2WrapperConsumerBase, IAttckGameEvent{
    event WatchDogExchange(address indexed owner, uint256 indexed id);
    event OpenProtectShell(address indexed owner, uint256 indexed startBlockNumber, uint256 indexed endBlockNumber);
    struct WatchDogInfo {
        uint256 id;
        uint256 protectShellStartBlockNumber;
        uint256 protectShellEndBlockNumber; 
        uint256 lastLaunchAttackRequestId; 
        uint256 lastBeAttackedRequestId;
        AttackStatus status;
    }

    struct Attack {
        uint256 chainLinkFees;
        address payable attacker;
        address target;
        uint256 attackRandom;
        uint256 reward;
        uint256 litter;
        bool attackResult;
        AttackStatus status;
    }

    enum AttackStatus {
        None,
        Pending,
        Completed
    }

    address immutable chickenCoopAddress;
    address immutable eggTokenAddress;
    address immutable litterTokenAddress;
    address immutable shellTokenAddress;
    mapping(address => WatchDogInfo) public watchDogInfos;
    uint256 constant maxOpenShellPeriod = 1000;
    uint256 constant cooldownPeriod = 100;
    uint256 constant openShellGap = 10;

    /** attack game variable **/
    address constant linkAddress = 0x779877A7B0D9E8603169DdbD7836e478b4624789;
    address constant vrfWrapperAddress = 0xab18414CD93297B0d12ac29E63Ca20f515b3DB46;
    uint32 constant callbackGasLimit = 1_000_000;
    uint32 constant numWords = 1;
    uint16 constant requestConfirmations = 10; // give victimn 10 blocks to protect their coop
    uint256 constant MANTISSA = 10 ** 18;
    uint256 constant attackFeeMantissa = 1.03 * 10 ** 18;
    mapping(uint256 => Attack) public attacks;
    uint256 constant minEggTokenReward = 300;
    uint256 constant maxEggTokenReward = 1000;
    uint256 constant maxLitterReward = 1000;
    uint256 constant targetShellReward = 100;
    uint256 constant closeFactorMantissa = 0.2 * 10 ** 18;

    constructor(address chickenCoop, address eggToken, address litterToken, address shellToken)
        VRFV2WrapperConsumerBase(linkAddress, vrfWrapperAddress) {
        chickenCoopAddress = chickenCoop;
        eggTokenAddress = eggToken;
        litterTokenAddress = litterToken;
        shellTokenAddress = shellToken;
    }

    function changeWatchDog(uint256 id, bool forceExchange) public payable {
        WatchDogInfo memory watchDog = watchDogInfos[msg.sender];
        require(watchDog.status != AttackStatus.Pending, "You are being attack.");
        require(id > totalDogCharacters, "Invalid watch dog id.");
        require(accountInfos[msg.sender].totalOwnWatchDogs[id], "You don't have this watch dog.");
        checkFee(msg.sender, msg.value);

        if(!forceExchange){
            uint256 currentBlock = getCurrentBlockNumber();
            uint256 shellEndBlockNumber = watchDog.protectShellEndBlockNumber;
            require(shellEndBlockNumber >= currentBlock, "Protect Shell is still open. You can not change watch dog now.");
        }
        watchDogInfos[msg.sender] = WatchDogInfo({
            id: id,
            protectShellStartBlockNumber: 0,
            protectShellEndBlockNumber: 0,
            lastLaunchAttackRequestId: 0,
            lastBeAttackedRequestId: 0,
            status: AttackStatus.None
        });
        emit WatchDogExchange(msg.sender, id);
        setAccountActionModifyBlock(msg.sender, AccountAction.ExchangeWatchDog);
    }

    function checkFee(address sender, uint value) internal {
        if(IToken(eggTokenAddress).balanceOf(sender) < handlingFeeEggToken){
            require(value >= handlingFeeEther, "Not enough Fee For Exchange.");
        } else{
            IToken(eggTokenAddress).burn(sender, handlingFeeEggToken);
        }
    }

    function openProtectShell(uint amount) public payable{
        uint balance = IToken(shellTokenAddress).balanceOf(msg.sender);
        // check input amount
        require(amount <= balance, "You don't have enough shell token.");
        require(amount <= maxOpenShellPeriod, "You can not open protect shell for so long.");

        checkFee(msg.sender, msg.value);

        uint256 currentBlock = getCurrentBlockNumber();
        uint256 shellEndBlockNumber = watchDogInfos[msg.sender].protectShellEndBlockNumber;
        require(shellEndBlockNumber + cooldownPeriod <= currentBlock, "You can not open protect shell now.");
        if(watchDogInfos[msg.sender].status == AttackStatus.Pending) revert("You are being attack.");

        watchDogInfos[msg.sender].protectShellStartBlockNumber = currentBlock + openShellGap ;
        watchDogInfos[msg.sender].protectShellEndBlockNumber = currentBlock + openShellGap + amount;
        IToken(shellTokenAddress).burn(msg.sender, amount);

        emit OpenProtectShell(msg.sender, currentBlock + cooldownPeriod, currentBlock + openShellGap + amount);
        setAccountActionModifyBlock(msg.sender, AccountAction.OpenProtectShell);
    }

    function isProtectShellOpen(address target,uint currentBlock) public view returns(bool){
        WatchDogInfo memory watchDog = watchDogInfos[target];
        if(currentBlock >= watchDog.protectShellStartBlockNumber && currentBlock <= watchDog.protectShellEndBlockNumber){
            return true;
        }
        return false;
    }

    function getAttackFee() external view returns (uint256) {
        uint vrfFee = VRF_V2_WRAPPER.calculateRequestPrice(callbackGasLimit);
        vrfFee = vrfFee * attackFeeMantissa / MANTISSA;
        return vrfFee;
    }

    function attack(address target) external returns (uint256) {
        // TODO : check attacker 活躍度
        require(checkActivated(msg.sender), "Insufficient active value ");

        require(target != address(0) && target != msg.sender, "Invalid attack");
        // TODO : check enough fee
        uint vrfFee = VRF_V2_WRAPPER.calculateRequestPrice(callbackGasLimit);
        vrfFee = vrfFee * attackFeeMantissa / MANTISSA;
        require(IERC20(linkAddress).balanceOf(msg.sender) >= vrfFee, "Not enough LINK!");
        
        // TODO : check target 活躍度
        require(checkActivated(target), "Target can not be attack.");

        // TODO : check target 防護罩是否開啟
        require(!isProtectShellOpen(target, getCurrentBlockNumber()), "Target's protect shell is open!");

        // TODO : check target is not being attack
        require(watchDogInfos[target].status != AttackStatus.Pending ,
            "Target can not be attack now .");
        watchDogInfos[target].status = AttackStatus.Pending;

        // TODO : target have egg token
        require(IToken(eggTokenAddress).balanceOf(target) > 0, "Target have no Egg Token!");

        // TODO : 垃圾桶為滿
        uint trashCanAmount = getTotalTrashCanAmount(target);
        require(IToken(litterTokenAddress).balanceOf(target) < trashCanAmount , "Trash can is full!");

        IERC20(linkAddress).transferFrom(msg.sender, address(this), vrfFee);

        uint256 requestId = requestRandomness(
            callbackGasLimit,
            requestConfirmations,
            numWords
        );

        watchDogInfos[msg.sender].lastLaunchAttackRequestId = requestId;
        watchDogInfos[target].lastBeAttackedRequestId = requestId;
        attacks[requestId] = Attack({
            chainLinkFees: VRF_V2_WRAPPER.calculateRequestPrice(callbackGasLimit),
            attacker: payable(msg.sender),
            target: target,
            attackRandom: 0,
            reward: 0,
            litter: 0,
            attackResult: false,
            status: AttackStatus.Pending
        });
        emit AttackRequest(requestId, msg.sender, target);
        return requestId;
    }


    function fulfillRandomWords(
        uint256 requestId,
        uint256[] memory randomWords
    ) internal override {
        Attack memory attackInfo = attacks[requestId];
        require(attackInfo.status == AttackStatus.Pending, "Attack already completed");
        require(attackInfo.chainLinkFees > 0, "Request not found");

        uint256 attackRandom = (randomWords[0] % 100) + 1;
        
        attackInfo.attackRandom = attackRandom;

        uint targetWatchDogId = watchDogInfos[attackInfo.target].id;
        mapping(uint256 => bool) storage protectNumber = dogsCatalog[targetWatchDogId].protectNumber;
        bool attackResult = !protectNumber[attackRandom];


        if(attackResult){
            // attack success
            IChickenCoop(chickenCoopAddress).payIncentive(attackInfo.target);
            giveRewardToAttacker(requestId);
            helpTargetOpenProtectShell(requestId);
        }

        attacks[requestId].attackResult = attackResult;
        attacks[requestId].status = AttackStatus.Completed;
        watchDogInfos[attackInfo.target].status = AttackStatus.Completed;
        emit AttackResult(requestId, attackInfo.attacker, attackInfo.target, attackResult);
        setAccountActionModifyBlock(attackInfo.attacker, AccountAction.AttackGame);
    }

    function giveRewardToAttacker(uint256 requestId) internal {
        Attack memory attackInfo = attacks[requestId];
        address attacker = attackInfo.attacker;
        address target = attackInfo.target;

        uint256 eggReward = giveEggToken(attacker, target);
        uint256 litterReward = dumpLitterToken(attacker, target);

        attacks[requestId].reward = eggReward;
        attacks[requestId].litter = litterReward;
    }

    function giveEggToken(address attacker, address target) internal returns (uint256) {
        uint256 rewardRatioMantissa = dogsCatalog[watchDogInfos[target].id].rewardRatioMantissa;
        uint256 targetEggBalance = IToken(eggTokenAddress).balanceOf(target);
        uint256 rewardMaxEggAmount = targetEggBalance * closeFactorMantissa / MANTISSA;
        uint256 rewardEggAmount = rewardMaxEggAmount * rewardRatioMantissa / MANTISSA;

        if(rewardEggAmount < minEggTokenReward){
            uint256 targetDebt = minEggTokenReward - rewardEggAmount;
            accountInfos[target].debtEggToken = targetDebt;
            rewardEggAmount = minEggTokenReward;
            IToken(eggTokenAddress).burn(target, rewardEggAmount);
            IToken(eggTokenAddress).mint(attacker, minEggTokenReward);
        } else if(rewardEggAmount > maxEggTokenReward){
            rewardEggAmount = maxEggTokenReward;
            IToken(eggTokenAddress).transfer(target, attacker, maxEggTokenReward);
        } else{
            IToken(eggTokenAddress).transfer(target, attacker, rewardEggAmount);
        }
        return rewardEggAmount;
    }

    function dumpLitterToken(address attacker, address target) internal returns (uint256){
        uint256 dumpRatioMantissa = dogsCatalog[watchDogInfos[target].id].dumpRatioMantissa;
        uint256 targetLitterBalance = IToken(litterTokenAddress).balanceOf(target);
        uint256 targetTrashCanAmount = getTotalTrashCanAmount(target);
        uint256 leftAmount = targetTrashCanAmount - targetLitterBalance;
        uint256 dumpMaxLitterAmount = leftAmount * closeFactorMantissa / MANTISSA;
        uint256 dumpLitterAmount = dumpMaxLitterAmount * dumpRatioMantissa / MANTISSA;
        
        uint256 attackerLitterBalance = IToken(litterTokenAddress).balanceOf(attacker);
        if(dumpLitterAmount > attackerLitterBalance){
            dumpLitterAmount = attackerLitterBalance;
        }

        if(dumpLitterAmount > maxLitterReward){
            dumpLitterAmount = maxLitterReward;
        }

        IToken(litterTokenAddress).transfer(attacker, target, dumpLitterAmount);
        return dumpLitterAmount;
    }

    function helpTargetOpenProtectShell(uint256 requestId) internal {
        Attack memory attackInfo = attacks[requestId];
        address target = attackInfo.target;
        uint256 currentBlock = getCurrentBlockNumber();
        watchDogInfos[target].protectShellStartBlockNumber = currentBlock;
        watchDogInfos[target].protectShellEndBlockNumber = currentBlock + targetShellReward;
        uint256 rewardRatioMantissa = dogsCatalog[watchDogInfos[target].id].rewardRatioMantissa;
        uint256 rewardEggAmount = targetShellReward * rewardRatioMantissa / MANTISSA;
        IToken(shellTokenAddress).mint(target, rewardEggAmount);
    }

    function getAttackStatus(uint256 requestId) external view returns (AttackStatus) {
        return attacks[requestId].status;
    }

    function getRandomWords(uint256 requestId) external view returns (uint256){
        return attacks[requestId].attackRandom;
    }

    function getAttackInfo(uint256 requestId) external view returns(Attack memory){
        return attacks[requestId];
    }
}