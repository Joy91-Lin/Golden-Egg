pragma solidity ^0.8.17;
import "./BirthFactory.sol";
import "./EggToken.sol";
import "./LitterToken.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract ChickenCoop is BirthFactory {
    event OutOfGasLimit(uint256 gasUsed, uint256 startCheckBlockNumber, uint256 endCheckBlockNumber);
    event LayEGGs(uint256 seatIndex, uint256 eggToken, uint256 litterToken, uint256 protectShell);
    event TrashCanFull(uint256 seatIndex, uint256 henId, uint256 missingEggToken);

    struct CoopSeat {
        bool isOpened;
        bool isExisted;
        uint256 id;
        uint256 layingTimes;
        uint256 foodIntake;
        uint256 layingLeftCycle;
        uint256 lastCheckBlockNumberPerSeat;
        // uint256 lastLayEggBlockNumber;
        // uint256 lastFeedBlockNumber;
    }

    struct CoopInfo{
        uint256 totalSeat;
        uint256 totalHen;
        uint256 trashCan;
        uint256 lastCheckBlockNumber;
        uint256 lastCheckHenIndex;
        uint256 debtEggToken;
    }
    mapping(uint256 => CoopSeat) coopSeats;
    mapping(address => CoopInfo) coopInfos;
    uint constant maxCoopSeat = 20;
    address immutable eggTokenAddress;
    address immutable litterTokenAddress;

    constructor(address eggToken, address litterToken) {
        eggTokenAddress = eggToken;
        litterTokenAddress = litterToken;

    }
    
    function layEggAndLitter(address target) public{
        CoopInfo memory coopInfo = coopInfos[target];
        uint currentBlockNumber = getCurrentBlockNumber();
        uint lastCheckBlockNumber = coopInfo.lastCheckBlockNumber;

        // if block number is not changed, do nothing
        if(lastCheckBlockNumber == currentBlockNumber){
            return;
        }

        uint gasUsed;
        uint gasLeft = gasleft();
        uint256 totalSeat = coopInfo.totalSeat;
        uint i;
        for(i=coopInfo.lastCheckHenIndex; i<totalSeat && gasUsed < 50_000; i++){
            CoopSeat memory coopSeat = coopSeats[i];
            if(coopSeat.isOpened && coopSeat.isExisted){
                // TODO : 計算食物消耗量
                uint blockDelta = currentBlockNumber - coopSeat.lastCheckBlockNumberPerSeat;
                coopSeat.lastCheckBlockNumberPerSeat = currentBlockNumber;
                uint256 validBlocks = calConsumeFoodIntake(coopSeat, blockDelta);
                
                // TODO : 檢查垃圾桶的垃圾量，滿就不動
                bool isFull = checkTrashCan(target, coopInfo.trashCan);

                // TODO : 減少layingleftCycle，並下獎勵和垃圾
                getReward(isFull, coopSeat, i, validBlocks);

            }

            gasUsed = gasUsed + gasLeft - gasleft();
            gasLeft = gasleft();
        }
        if(gasUsed >= 50_000){
            emit OutOfGasLimit(gasUsed, coopInfo.lastCheckHenIndex, i);
            coopInfos[target].lastCheckHenIndex = i;
        }else{
            coopInfos[target].lastCheckHenIndex = 0;
        }
    }

    function calConsumeFoodIntake(CoopSeat memory coopSeat, uint blockDelta) internal returns (uint256){
        HenCharacter memory hen = henCharacters[coopSeat.id];
        uint256 consumeFoodForOneBlock = hen.consumeFoodForOneBlock;
        uint256 foodIntake = coopSeat.foodIntake;
        uint256 totalConsumeFood = consumeFoodForOneBlock * blockDelta;

        if(foodIntake == 0){
            return 0;
        }

        if(foodIntake >= totalConsumeFood){
            coopSeats[coopSeat.id].foodIntake = foodIntake - totalConsumeFood;
            return blockDelta;
        }else{
            coopSeats[coopSeat.id].foodIntake = foodIntake % consumeFoodForOneBlock;
            return foodIntake / consumeFoodForOneBlock;
        }
    }

    function checkTrashCan(address target, uint maxTrashCanAmount) internal returns (bool){
        uint litterBalance = IERC20(litterTokenAddress).balanceOf(target);

        if(litterBalance >= maxTrashCanAmount){
            return true;
        }
        return false;
    }

    function getReward(bool isFull, CoopSeat memory coopSeat,  uint seatIndex, uint validBlock) internal {
        if(validBlock == 0){
            return;
        }
        uint leftBlock = coopSeat.layingLeftCycle;
        HenCharacter memory hen = henCharacters[coopSeat.id];
        uint eggTokenAmount = hen.unitEggToken;
        uint litterTokenAmount = hen.unitLitterToken;
        if(leftBlock <= validBlock){
            if(isFull){
                emit TrashCanFull(seatIndex,coopSeat.id, eggTokenAmount);
            }else{
                // give egg token and litter token and protect shell
                IERC20(eggTokenAddress).mint(msg.sender, eggTokenAmount);
                IERC20(litterTokenAddress).mint(msg.sender, litterTokenAmount);
                if(++coopSeat.layingTimes % hen.protectShellPeriod == 0){
                    // give protect shell
                }
            }
            uint newDelta = leftBlock-validBlock;
            if(newDelta == 0){
                coopSeat.layingLeftCycle = hen.layingCycle;
            } else{
                coopSeat.layingLeftCycle = newDelta;
            }
        }else{
            coopSeat.layingLeftCycle = leftBlock - validBlock;
        }
    }

    function getCurrentBlockNumber() public view returns (uint256){
        return block.number;
    }
}