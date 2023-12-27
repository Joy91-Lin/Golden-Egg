pragma solidity ^0.8.17;
import "./BirthFactory.sol";
import "./Token.sol";
import "./GoldenCore.sol";
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
        uint256 protectShellCount;
        uint256 foodIntake;
        uint256 layingLeftCycle;
        uint256 lastCheckBlockNumberPerSeat;
    }

    struct CoopInfo{
        uint256 totalSeat;
        uint256 totalHen;
        uint256 trashCan;
        uint256 lastCheckBlockNumber;
        uint256 lastCheckHenIndex;
        uint256 debtEggToken;
    }
    mapping(address => mapping(uint256 => CoopSeat)) coopSeats;
    mapping(address => CoopInfo) coopInfos;
    uint constant maxCoopSeat = 20;
    address immutable eggTokenAddress;
    address immutable litterTokenAddress;
    address immutable shellTokenAddress;

    constructor(address eggToken, address litterToken, address shellToken)  {
        eggTokenAddress = eggToken;
        litterTokenAddress = litterToken;
        shellTokenAddress = shellToken;
    }
    
    /**
     * @dev let hen lay egg and litter and get protect shell
     */
    function payIncentive(address target) public {
        CoopInfo memory coopInfo = coopInfos[target];
        uint currentBlockNumber = getCurrentBlockNumber();
        uint lastCheckBlockNumber = coopInfo.lastCheckBlockNumber;

        // if block number is not changed, do nothing
        if(lastCheckBlockNumber == currentBlockNumber){
            return;
        }

        // check all coop seat
        uint gasUsed;
        uint gasLeft = gasleft();
        uint256 totalSeat = coopInfo.totalSeat;
        uint i;
        for(i=coopInfo.lastCheckHenIndex; i<totalSeat && gasUsed < 50_000; i++){
            CoopSeat memory coopSeat = coopSeats[target][i];
            if(coopSeat.isOpened && coopSeat.isExisted){
                // TODO : 計算食物消耗量
                uint blockDelta = currentBlockNumber - coopSeat.lastCheckBlockNumberPerSeat;
                coopSeat.lastCheckBlockNumberPerSeat = currentBlockNumber;
                uint256 validBlocks = calConsumeFoodIntake(target, i, blockDelta);
                
                // TODO : 檢查垃圾桶的垃圾量
                bool isFull = checkTrashCan(target, coopInfo.trashCan);

                // TODO : 減少layingleftCycle，並下獎勵和垃圾
                getReward(target, i, isFull, validBlocks);

                coopSeats[target][i].lastCheckBlockNumberPerSeat = currentBlockNumber;
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

    /**
     * @dev use foodIntake to calculate how many vaild blocks in blockDelta
     */
    function calConsumeFoodIntake(address target, uint coopSeatIndex, uint blockDelta) internal returns (uint256){
        HenCharacter memory hen = henCharacters[coopSeats[target][coopSeatIndex].id];
        uint256 consumeFoodForOneBlock = hen.consumeFoodForOneBlock;
        uint256 foodIntake = coopSeats[target][coopSeatIndex].foodIntake;
        uint256 totalConsumeFood = consumeFoodForOneBlock * blockDelta;

        if(foodIntake == 0 || blockDelta == 0){
            return 0;
        }

        // check if foodIntake is enough for totalConsumeFood
        if(foodIntake >= totalConsumeFood){
            coopSeats[target][coopSeatIndex].foodIntake = foodIntake - totalConsumeFood;
            return blockDelta;
        }else{
            coopSeats[target][coopSeatIndex].foodIntake = foodIntake % consumeFoodForOneBlock;
            return foodIntake / consumeFoodForOneBlock;
        }
    }

    /**
     * @dev check if trash can is full
     */
    function checkTrashCan(address target, uint maxTrashCanAmount) internal view returns (bool){
        uint litterBalance = IToken(litterTokenAddress).balanceOf(target);

        if(litterBalance >= maxTrashCanAmount){
            return true;
        }
        return false;
    }
    /**
     * @dev give reward to target
     */
    function getReward(address target, uint seatIndex, bool isFull, uint validBlock) internal {
        if(validBlock == 0){
            return;
        }
        CoopSeat memory coopSeat = coopSeats[target][seatIndex];
        uint leftBlock = coopSeat.layingLeftCycle;
        HenCharacter memory hen = henCharacters[coopSeat.id];
        if(leftBlock <= validBlock){
            (uint nowLayingTimes, uint newLeftLayingBlock) = calLeftLayingBlock(leftBlock, validBlock, hen.unitEggToken);
            coopSeats[target][seatIndex].layingLeftCycle = newLeftLayingBlock;
            if(isFull){
                uint increaseEggToken = hen.unitEggToken * nowLayingTimes;
                emit TrashCanFull(seatIndex, coopSeat.id, increaseEggToken);
            }else{
                // give egg token 
                uint eggTokenAmount = giveEggToken(target, hen.unitEggToken, nowLayingTimes);

                // give litter token
                uint litterTokenAmount = giveLitterToken(target, hen.unitLitterToken, nowLayingTimes);

                // give protect shell
                uint shellTokenAmount = giveProtectShell(target, seatIndex, hen.protectShellPeriod, nowLayingTimes);

                emit LayEGGs(seatIndex, eggTokenAmount, litterTokenAmount, shellTokenAmount);
            }
        }else{
            coopSeats[target][seatIndex].layingLeftCycle = leftBlock - validBlock;
        }

    }
    function giveEggToken(address target, uint unitEggToken, uint nowLayingTimes) internal  returns (uint nowLayEggAmount){
        uint increaseEggToken = unitEggToken * nowLayingTimes;
        uint debtEggToken = coopInfos[target].debtEggToken;
        if(debtEggToken >=  increaseEggToken){
            coopInfos[target].debtEggToken = debtEggToken - increaseEggToken;
        }else{
            nowLayEggAmount = increaseEggToken - debtEggToken;
            coopInfos[target].debtEggToken = 0;
            IToken(eggTokenAddress).mint(target, nowLayEggAmount);
        }
        return nowLayEggAmount;
    }

    function giveLitterToken(address target, uint unitLitterToken, uint nowLayingTimes) internal  returns (uint nowLitterAmount){
        nowLitterAmount = unitLitterToken * nowLayingTimes;
        IToken(litterTokenAddress).mint(target, nowLitterAmount);
        return nowLitterAmount;
    }
    function giveProtectShell(address target, uint seatIndex, uint shellPeriod, uint nowLayingTimes) internal  returns (uint nowShellAmount){
        CoopSeat memory coopSeat = coopSeats[target][seatIndex];
        uint preShellAmount = coopSeat.protectShellCount;
        uint totalLayingTimes = coopSeat.layingTimes + nowLayingTimes;
        uint totalProtectShell = totalLayingTimes / shellPeriod;
        nowShellAmount = totalProtectShell - preShellAmount;

        if(nowShellAmount > 0){
            IToken(shellTokenAddress).mint(target, nowShellAmount);
        }

        coopSeats[target][seatIndex].layingTimes = totalLayingTimes;
        coopSeats[target][seatIndex].protectShellCount = preShellAmount + nowShellAmount; 
        return nowShellAmount;
    }

    /**
     * @dev calculate how many times hen can lay egg in validBlock
     */
    function calLeftLayingBlock(uint leftBlock, uint validBlock, uint unitEggToken) internal pure returns (uint nowLayingTimes, uint newLeftLayingBlock){
        uint deltaBlock = validBlock - leftBlock;
        nowLayingTimes = 1 + deltaBlock / unitEggToken;
        newLeftLayingBlock = unitEggToken - deltaBlock % unitEggToken;
        return (nowLayingTimes, newLeftLayingBlock);
    }

    function getCurrentBlockNumber() public view returns (uint256){
        return block.number;
    }

    function helpFeedHen(address target, uint seatIndex, uint feedAmount) public {
        feedHen(msg.sender, target, seatIndex, feedAmount);
    }

    function feedOwnHen(uint seatIndex, uint feedAmount) public {
        feedHen(msg.sender, msg.sender, seatIndex, feedAmount);
    }
    
    function feedHen(address sender, address target, uint seatIndex, uint feedAmount) public{
        CoopSeat memory coopSeat = coopSeats[target][seatIndex];
        require(coopSeat.isOpened, "seat is not opened");
        require(coopSeat.isExisted, "No hen in this seat");
        require(feedAmount > 0, "feed amount must be greater than 0");
        require(IToken(eggTokenAddress).balanceOf(sender) >= feedAmount, "Not enough egg token");

        HenCharacter memory hen = henCharacters[coopSeat.id];
        uint256 foodIntake = coopSeat.foodIntake;
        uint256 maxFoodIntake = hen.maxFoodIntake;
        uint256 totalFoodIntake = foodIntake + feedAmount;

        if(totalFoodIntake > maxFoodIntake){
            totalFoodIntake = maxFoodIntake;
            feedAmount = maxFoodIntake - foodIntake;
        }
        coopSeats[target][seatIndex].foodIntake = totalFoodIntake;
        IToken(eggTokenAddress).burn(sender, feedAmount);
    }

    function putUpHen() public {
    }

    function takeDownHen() public {
    }
}