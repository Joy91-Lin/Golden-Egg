pragma solidity ^0.8.17;

import "chainlink/vrf/VRFV2WrapperConsumerBase.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./GoldenCore.sol";

contract AttackGame is VRFV2WrapperConsumerBase {
    event AttackRequest(
        uint256 indexed requestId,
        address indexed requester,
        address indexed target
    );
    event AttackResult(
        uint256 indexed requestId,
        address indexed requester,
        address indexed target,
        bool result
    );

    struct Attack {
        uint256 chainLinkFees;
        address payable attacker;
        address target;
        uint256 attackRandom;
        uint256 rewardRandom;
        uint256 litterRandom;
        bool attackResult;
        AttackStatus status;
    }

    enum AttackStatus {
        Pending,
        Completed,
        Revert
    }

    mapping(uint256 => Attack) public attacks;

    address constant linkAddress = 0x779877A7B0D9E8603169DdbD7836e478b4624789;
    address constant vrfWrapperAddress =
        0xab18414CD93297B0d12ac29E63Ca20f515b3DB46;
    uint32 constant callbackGasLimit = 1_000_000;
    uint32 constant numWords = 3;
    uint16 constant requestConfirmations = 3;
    uint256 constant MANTISSA = 10 ** 18;
    uint256 constant attackFeeMantissa = 1.02 * 10 ** 18;
    GoldenCore immutable goldenCore;

    constructor(address goldenCore) VRFV2WrapperConsumerBase(linkAddress, vrfWrapperAddress) {
        goldenCore = GoldenCore(goldenCore);
    }

    function attack(address target) external returns (uint256) {
        require(target != address(0) || target != msg.sender, "Invalid target");
        // TODO : check enough fee
        uint vrfFee = VRF_V2_WRAPPER.calculateRequestPrice(callbackGasLimit);
        vrfFee = vrfFee * attackFeeMantissa / MANTISSA;
        require(IERC20(linkAddress).balanceOf(msg.sender) >= vrfFee, "Not enough LINK!");
        
        // TODO : check target 活躍度
        require(goldenCore.checkActivated(target), "Target can not be attack.");

        // TODO : 若target address的reward為0且垃圾桶為滿，則不可攻擊
        
        
        // TODO : check target 防護罩是否開啟

        IERC20(linkAddress).transferFrom(msg.sender, address(this), vrfFee);

        uint256 requestId = requestRandomness(
            callbackGasLimit,
            requestConfirmations,
            numWords
        );

        attacks[requestId] = Attack({
            chainLinkFees: VRF_V2_WRAPPER.calculateRequestPrice(callbackGasLimit),
            attacker: payable(msg.sender),
            target: target,
            attackRandom: 0,
            rewardRandom: 0,
            litterRandom: 0,
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
        require(attacks[requestId].status == AttackStatus.Pending, "Attack already completed");
        require(attacks[requestId].chainLinkFees > 0, "Request not found");
        // TODO: check target address是否開啟防護罩AttackStatus->revert

        uint256 attackRandom = (randomWords[0] % 100) + 1;
        uint256 rewardRandom = (randomWords[1] % 100) + 1; // 100 will be replaced by target address's half balance 
        uint256 litterRandom = (randomWords[2] % 100) + 1; // 100 will be replaced by target address's half trash can amount
        
        attacks[requestId].attackRandom = attackRandom;
        attacks[requestId].rewardRandom = rewardRandom;
        attacks[requestId].litterRandom = litterRandom;
        // TODO : if attack success, 
        // TODO : add attackRandom to target's watch dog
        // TODO : turn on protect shell for next 480 block -> 2 hr
        // TODO : transfer reward to attacker
        // TODO : transfer litter to target

        attacks[requestId].status = AttackStatus.Completed;
        emit AttackResult(
            requestId,
            attacks[requestId].attacker,
            attacks[requestId].target,
            attacks[requestId].attackResult
        );
    }

    function getAttackStatus(uint256 requestId) external view returns (AttackStatus) {
        return attacks[requestId].status;
    }

    function getRandomWords(uint256 requestId)
        external
        view
        returns (
            uint256 attackRandom,
            uint256 rewardRandom,
            uint256 litterRandom
        )
    {
        return (
            attacks[requestId].attackRandom,
            attacks[requestId].rewardRandom,
            attacks[requestId].litterRandom
        );
    }

    function getAttackInfo(uint256 requestId) external view returns(Attack memory){
        return attacks[requestId];
    }
}
