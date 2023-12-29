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
    uint256 constant targetShellReward = 300;
    uint256 constant closeFactorMantissa = 0.2 * 10 ** 18;

    constructor(address chickenCoop, address eggToken, address litterToken, address shellToken)
        VRFV2WrapperConsumerBase(linkAddress, vrfWrapperAddress) {
        chickenCoopAddress = chickenCoop;
        eggTokenAddress = eggToken;
        litterTokenAddress = litterToken;
        shellTokenAddress = shellToken;
    }

    function openProtectShell() public{
        
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

        // TODO : check target is not being attack
        require(watchDogInfos[target].status != AttackStatus.Pending, "Target is being attack.");
        watchDogInfos[target].status = AttackStatus.Pending;

        // TODO : check target 防護罩是否開啟
        require(!isProtectShellOpen(target, getCurrentBlockNumber()), "Target's protect shell is open!");

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
        uint256 stealRatioMantissa = dogsCatalog[watchDogInfos[target].id].stealRatioMantissa;
        uint256 targetEggBalance = IToken(eggTokenAddress).balanceOf(target);
        uint256 stealMaxEggAmount = targetEggBalance * closeFactorMantissa / MANTISSA;
        uint256 stealEggAmount = stealMaxEggAmount * stealRatioMantissa / MANTISSA;

        if(stealEggAmount < minEggTokenReward){
            uint256 targetDebt = minEggTokenReward - stealEggAmount;
            accountInfos[target].debtEggToken = targetDebt;
            stealEggAmount = minEggTokenReward;
            IToken(eggTokenAddress).burn(target, stealEggAmount);
            IToken(eggTokenAddress).mint(attacker, minEggTokenReward);
        } else if(stealEggAmount > maxEggTokenReward){
            stealEggAmount = maxEggTokenReward;
            IToken(eggTokenAddress).transfer(target, attacker, maxEggTokenReward);
        } else{
            IToken(eggTokenAddress).transfer(target, attacker, stealEggAmount);
        }
        return stealEggAmount;
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
        IToken(shellTokenAddress).mint(target, targetShellReward);
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