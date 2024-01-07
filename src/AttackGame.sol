pragma solidity ^0.8.21;

import "chainlink/vrf/VRFV2WrapperConsumerBase.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./GoldenEgg.sol";
import "./Token.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
interface IAttckGameEvent{
    event AttackRequest(uint256 indexed requestId, address indexed requester, address indexed target);
    event AttackResult(uint256 indexed requestId, address indexed requester, address indexed target, bool result);
}
contract AttackGame is VRFV2WrapperConsumerBase, Ownable, IAttckGameEvent{
    

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

    /** attack game variable **/
    address constant linkAddress = 0x779877A7B0D9E8603169DdbD7836e478b4624789;
    address constant vrfWrapperAddress = 0xab18414CD93297B0d12ac29E63Ca20f515b3DB46;
    uint32 constant callbackGasLimit = 1_000_000;
    uint32 constant numWords = 1;
    uint16 constant requestConfirmations = 10; // give victimn 10 blocks to protect their coop
    uint256 constant attackFeeMantissa = 1.03 * 10 ** 18;
    mapping(uint256 => Attack) attacks;
    uint256 constant minEggTokenReward = 300 * 10 ** 18;
    uint256 constant maxEggTokenReward = 1000 * 10 ** 18;
    uint256 constant minLitterReward = 10 * 10 ** 18;
    uint256 constant maxLitterReward = 1000 * 10 ** 18;
    uint256 constant targetShellReward = 100 * 10 ** 18;
    uint256 constant closeFactorMantissa = 0.2 * 10 ** 18;
    uint256 constant MANTISSA = 10 ** 18;
    GoldenEgg goldenEgg;
    address eggTokenAddress;
    address litterTokenAddress;
    address shellTokenAddress;

    constructor() VRFV2WrapperConsumerBase(linkAddress, vrfWrapperAddress) Ownable(msg.sender) {}

    function setUpAddress(
        address _eggTokenAddress,
        address _litterTokenAddress,
        address _shellTokenAddress,
        address _goldenEggAddress
    ) external onlyOwner {
        eggTokenAddress = _eggTokenAddress;
        litterTokenAddress = _litterTokenAddress;
        shellTokenAddress = _shellTokenAddress;
        goldenEgg = GoldenEgg(_goldenEggAddress);
    }

    function getAttackFee() external view returns (uint256) {
        uint vrfFee = VRF_V2_WRAPPER.calculateRequestPrice(callbackGasLimit);
        vrfFee = vrfFee * attackFeeMantissa / MANTISSA;
        return vrfFee;
    }

    function attack(address target) external returns (uint256) {
        goldenEgg.isAccountJoinGame(msg.sender);
        goldenEgg.isAccountJoinGame(target);
        // check attacker 活躍度
        require(goldenEgg.checkActivated(msg.sender), "Insufficient active value ");

        require(target != address(0) && target != msg.sender, "Invalid attack");
        // check enough fee
        uint vrfFee = VRF_V2_WRAPPER.calculateRequestPrice(callbackGasLimit);
        vrfFee = vrfFee * attackFeeMantissa / MANTISSA;
        require(IERC20(linkAddress).balanceOf(msg.sender) >= vrfFee, "Not enough LINK!");
        
        // check target 活躍度
        require(goldenEgg.checkActivated(target), "Target can not be attack.");

        // check target 防護罩是否開啟
        require(!goldenEgg.isProtectShellOpen(target), "Target's protect shell is open!");

        // check target is not being attack
        require(goldenEgg.canAttack(target), "Target can not be attack now .");

        // target have egg token
        require(IToken(eggTokenAddress).balanceOf(target) > minEggTokenReward, "Target is a shortage of eggToken!");

        // 垃圾桶為滿
        require(IToken(litterTokenAddress).balanceOf(target) <= goldenEgg.getTotalTrashCanAmount(target) - minLitterReward , "Trash can is around full!");

        IERC20(linkAddress).transferFrom(msg.sender, address(this), vrfFee);

        uint256 requestId = requestRandomness(
            callbackGasLimit,
            requestConfirmations,
            numWords
        );

        goldenEgg.setForAttackGameStart(requestId, msg.sender, target);

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

        uint256 attackRandom = (randomWords[0] % goldenEgg.attackRange()) + 1;
        
        attackInfo.attackRandom = attackRandom;

        uint256 durabilityOfProtectNumber = goldenEgg.getAccountProtectNumbers(attackInfo.target, attackRandom);
        bool attackResult = false;
        uint256 targetDebt = 0;
        // if(durabilityOfProtectNumber > 0){
        //     // attack fail
        //     goldenEgg.attackGameFailed(attackInfo.target, attackRandom);
        // } else {
        if(durabilityOfProtectNumber == 0){
            // attack success
            attackResult = true;
            targetDebt = giveRewardToAttacker(requestId);
            helpTargetOpenProtectShell(requestId);
        }

        attacks[requestId].attackResult = attackResult;
        attacks[requestId].status = AttackStatus.Completed;
        goldenEgg.setForAttackGameEnd(attackInfo.attacker, attackInfo.target, attackResult, attackRandom, targetDebt);
        emit AttackResult(requestId, attackInfo.attacker, attackInfo.target, attackResult);
    }

    function giveRewardToAttacker(uint256 requestId) internal returns (uint256) {
        Attack memory attackInfo = attacks[requestId];
        address attacker = attackInfo.attacker;
        address target = attackInfo.target;

        (uint256 eggReward, uint targetDebt)= giveEggToken(attacker, target);
        uint256 litterReward = dumpLitterToken(attacker, target);

        attacks[requestId].reward = eggReward;
        attacks[requestId].litter = litterReward;
        return targetDebt;
    }

    function giveEggToken(address attacker, address target) internal returns (uint256, uint256) {
        uint256 targetDogId = goldenEgg.getWatchDogInfo(target).id;
        uint256 lostPercentageMantissa = goldenEgg.getDogCatalog(targetDogId).lostPercentageMantissa;
        uint256 targetEggBalance = IToken(eggTokenAddress).balanceOf(target);
        uint256 rewardMaxEggAmount = targetEggBalance * closeFactorMantissa / MANTISSA;
        uint256 rewardEggAmount = rewardMaxEggAmount * lostPercentageMantissa / MANTISSA;
        uint256 targetDebt = 0;
        if(rewardEggAmount < minEggTokenReward){
            if(minEggTokenReward < targetEggBalance){
                rewardEggAmount = minEggTokenReward;
                IToken(eggTokenAddress).transferFrom(target, attacker, minEggTokenReward);
            } else{
                targetDebt = minEggTokenReward - rewardEggAmount;
                IToken(eggTokenAddress).burn(target, rewardEggAmount);
                IToken(eggTokenAddress).mint(attacker, minEggTokenReward);
                rewardEggAmount = minEggTokenReward;
            }
        } else if(rewardEggAmount > maxEggTokenReward){
            rewardEggAmount = maxEggTokenReward;
            IToken(eggTokenAddress).transferFrom(target, attacker, maxEggTokenReward);
        } else{
            IToken(eggTokenAddress).transferFrom(target, attacker, rewardEggAmount);
        }
        return (rewardEggAmount, targetDebt);
    }

    function dumpLitterToken(address attacker, address target) internal returns (uint256){
        uint256 targetDogId = goldenEgg.getWatchDogInfo(target).id;
        uint256 lostPercentageMantissa = goldenEgg.getDogCatalog(targetDogId).lostPercentageMantissa;
        uint256 targetLitterBalance = IToken(litterTokenAddress).balanceOf(target);
        uint256 targetTrashCanAmount = goldenEgg.getTotalTrashCanAmount(target);
        uint256 leftAmount = targetTrashCanAmount - targetLitterBalance;
        uint256 dumpMaxLitterAmount = leftAmount * closeFactorMantissa / MANTISSA;
        uint256 dumpLitterAmount = dumpMaxLitterAmount * lostPercentageMantissa / MANTISSA;
        
        uint256 attackerLitterBalance = IToken(litterTokenAddress).balanceOf(attacker);
        if(dumpLitterAmount > attackerLitterBalance){
            dumpLitterAmount = attackerLitterBalance;
        }

        if(dumpLitterAmount > maxLitterReward){
            dumpLitterAmount = maxLitterReward;
        }
        if(dumpLitterAmount > 0)
            IToken(litterTokenAddress).transferFrom(attacker, target, dumpLitterAmount);
        return dumpLitterAmount;
    }

    function helpTargetOpenProtectShell(uint256 requestId) internal {
        Attack memory attackInfo = attacks[requestId];
        address target = attackInfo.target;
        uint256 targetDogId = goldenEgg.getWatchDogInfo(target).id;
        uint256 compensationPercentageMantissa = goldenEgg.getDogCatalog(targetDogId).compensationPercentageMantissa;
        uint256 rewardEggAmount = targetShellReward * compensationPercentageMantissa / MANTISSA;
        IToken(shellTokenAddress).mint(target, rewardEggAmount);
    }

    function getAttackInfo(uint256 requestId) external view returns(Attack memory){
        return attacks[requestId];
    }

    function takeOutIncome() public onlyOwner{
        IERC20(linkAddress).transfer(owner(), IERC20(linkAddress).balanceOf(address(this)));
    }
    
    function takeOutIncome(uint linkBalance) public onlyOwner{
        IERC20(linkAddress).transfer(owner(), linkBalance);
    }

    function getContractBalance() public onlyOwner view returns(uint256){
        return IERC20(linkAddress).balanceOf(address(this));
    }

}
