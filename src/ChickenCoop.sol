pragma solidity ^0.8.21;

import "./BirthFactory.sol";
import "./Token.sol";
import "./GoldenCore.sol";

interface IChickenCoop{
    function putUpHen(uint seatIndex, uint henId, bool forceExchange, uint feedAmount) external payable;
    function takeDownHen(uint seatIndex, bool forceExchange) external payable;
    function helpFeedHen(address target, uint seatIndex, uint feedAmount) external;
    function feedOwnHen(uint seatIndex, uint feedAmount) external;
    function showHenHunger(address target) external view returns (ChickenCoop.FoodIntake[] memory);
    function getAllSeatStatus(bool _payIncentive) external returns (ChickenCoop.CoopSeat[] memory);
    function payIncentive(address target) external;
}

interface IChickenCoopEvent{
    event PutUpHenToCoopSeats(address indexed sender, uint256 seatIndex, uint256 henId);
    event TakeDownHenFromCoopSeats(address indexed sender, uint256 seatIndex, uint256 henId);
    event FeedHen(address indexed sender, address indexed target, uint256 seatIndex, uint256 feedAmount);
    event OutOfGasLimit(uint256 gasUsed, uint256 startCheckBlockNumber, uint256 endCheckBlockNumber);
    event LayEGGs(uint256 seatIndex, uint256 eggToken, uint256 litterToken, uint256 protectShell);
    event TrashCanFull(uint256 seatIndex, uint256 henId, uint256 missingEggToken);
}

contract ChickenCoop is BirthFactory, IChickenCoopEvent {

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


    struct FoodIntake{
        uint seatIndex;
        bool isExisted;
        uint256 id;
        uint256 foodIntake;
        uint256 maxFoodIntake;
    }

    // start from 1
    mapping(address => mapping(uint256 => CoopSeat)) coopSeats;

    function putUpHen(uint seatIndex, uint henId, bool forceExchange, uint feedAmount) public payable {
        exchangeCoopSeatsPreCheck(msg.sender, msg.value, seatIndex);
        
        ownHenId(msg.sender, henId);

        CoopSeat memory coopSeat = coopSeats[msg.sender][seatIndex];
        if(!forceExchange){
            payIncentive(msg.sender);

            require(!coopSeat.isExisted, 
                "Already have hen in this seat.Please use takeDownHen or Force Mode to exchange hen.");
        }

        uint henInCoopCount = accountInfos[msg.sender].hensInCoop[henId];
        accountInfos[msg.sender].hensInCoop[henId] = henInCoopCount + 1;
        coopSeats[msg.sender][seatIndex] = 
            CoopSeat(true, 
                true, 
                henId, 
                0, 
                0,
                0, 
                hensCatalog[henId].layingCycle, 
                getCurrentBlockNumber());
        emit PutUpHenToCoopSeats(msg.sender, seatIndex, henId);
        setAccountActionModifyBlock(msg.sender, AccountAction.ExchangeHen);

        if(feedAmount > 0){
            feedHen(msg.sender, msg.sender, seatIndex, feedAmount);
        }
    }

    function takeDownHen(uint seatIndex, bool forceExchange) public payable {
        exchangeCoopSeatsPreCheck(msg.sender, msg.value, seatIndex);

        CoopSeat memory coopSeat = coopSeats[msg.sender][seatIndex];
        require(coopSeat.isExisted, "Seat is already empty.");

        if(!forceExchange){
            payIncentive(msg.sender);

            if(coopSeat.foodIntake > 0 || coopSeat.layingLeftCycle > 0){
                    revert("Not ready to take down.");
            }
        }
        
        uint henId = coopSeat.id;
        uint henInCoopCount = accountInfos[msg.sender].hensInCoop[henId];
        if(henId > 0 && henInCoopCount > 0) {
            accountInfos[msg.sender].hensInCoop[henId] = henInCoopCount - 1;
        }
        coopSeats[msg.sender][seatIndex] = CoopSeat(true, false, 0, 0, 0, 0, 0, 0);
        emit TakeDownHenFromCoopSeats(msg.sender, seatIndex, henId);
        setAccountActionModifyBlock(msg.sender, AccountAction.ExchangeHen);
    }

    function ownHenId(address sender, uint henId) internal view {
        require(henId > totalHenCharacters, "Invalid hen id.");
        uint256 totalHen = accountInfos[sender].totalOwnHens[henId];
        uint256 henInCoop = accountInfos[sender].hensInCoop[henId];
        require(totalHen - henInCoop > 0 , "Insufficient Hen.");
    }

    function exchangeCoopSeatsPreCheck(address sender, uint value, uint seatIndex) internal {
        isAccountJoinGame(sender);
        checkSeatExist(sender, seatIndex);
        checkExchangeFee(sender, value);
    }


    function checkSeatExist(address sender, uint index) internal view {
        uint256 totalSeat = accountInfos[sender].totalCoopSeats;
        require(index > totalSeat, "Seat index have not been opened.");
        require(coopSeats[sender][index].isOpened, "Seat is not opened.");
    }

    function checkExchangeFee(address sender, uint value) internal {
        if(value > 0){
            require(value == handlingFeeEther, "Incorrect fee.");
        } else{
            uint256 handlingFeeEggToken = handlingFeeEther * IToken(eggTokenAddress).getRatioOfEth();
            require(IToken(eggTokenAddress).balanceOf(sender) >= handlingFeeEggToken, "Not enough egg token.");
            IToken(eggTokenAddress).burn(sender, handlingFeeEggToken);
        }
    }
    
    /**
     * @dev let hen lay egg and litter and get protect shell
     */
    function payIncentive(address target) public {
        AccountInfo storage accountInfo = accountInfos[target];
        uint currentBlockNumber = getCurrentBlockNumber();
        uint lastCheckBlockNumber = accountInfo.lastPayIncentiveBlockNumber;

        // if block number is not changed, do nothing
        if(lastCheckBlockNumber == currentBlockNumber){
            return;
        }

        // check all coop seat
        uint gasUsed;
        uint gasLeft = gasleft();
        uint256 totalSeat = accountInfo.totalCoopSeats;
        uint i;
        for(i=accountInfo.lastCheckHenIndex; i<totalSeat && gasUsed < 50_000; i++){
            CoopSeat memory coopSeat = coopSeats[target][i];
            if(coopSeat.isOpened && coopSeat.isExisted){
                // TODO : 計算食物消耗量
                uint blockDelta = currentBlockNumber - coopSeat.lastCheckBlockNumberPerSeat;
                coopSeat.lastCheckBlockNumberPerSeat = currentBlockNumber;
                uint256 validBlocks = calConsumeFoodIntake(target, i, blockDelta);
                
                // TODO : 檢查垃圾桶的垃圾量
                bool isFull = checkTrashCan(target, accountInfo.totalTrashCan);

                // TODO : 減少layingleftCycle，並下獎勵和垃圾
                getReward(target, i, isFull, validBlocks);

                coopSeats[target][i].lastCheckBlockNumberPerSeat = currentBlockNumber;
            }

            gasUsed = gasUsed + gasLeft - gasleft();
            gasLeft = gasleft();
        }

        if(gasUsed >= 50_000){
            emit OutOfGasLimit(gasUsed, accountInfo.lastCheckHenIndex, i);
            accountInfos[target].lastCheckHenIndex = i;
        }else{
            accountInfos[target].lastCheckHenIndex = 0;
        }

        accountInfos[target].lastPayIncentiveBlockNumber = currentBlockNumber;
        setAccountActionModifyBlock(target, AccountAction.PayIncentive);
    }

    /**
     * @dev use foodIntake to calculate how many vaild blocks in blockDelta
     */
    function calConsumeFoodIntake(address target, uint coopSeatIndex, uint blockDelta) internal returns (uint256){
        HenCharacter memory hen = hensCatalog[coopSeats[target][coopSeatIndex].id];
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
        HenCharacter memory hen = hensCatalog[coopSeat.id];
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
        uint debtEggToken = accountInfos[target].debtEggToken;
        if(debtEggToken >=  increaseEggToken){
            accountInfos[target].debtEggToken = debtEggToken - increaseEggToken;
        }else{
            nowLayEggAmount = increaseEggToken - debtEggToken;
            accountInfos[target].debtEggToken = 0;
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

    function helpFeedHen(address target, uint seatIndex, uint feedAmount) public {
        isAccountJoinGame(target);

        payIncentive(target);

        feedHen(msg.sender, target, seatIndex, feedAmount);
    }

    function feedOwnHen(uint seatIndex, uint feedAmount) public {
        payIncentive(msg.sender);

        feedHen(msg.sender, msg.sender, seatIndex, feedAmount);
    }
    
    function feedHen(address sender, address target, uint seatIndex, uint feedAmount) internal {
        CoopSeat memory coopSeat = coopSeats[target][seatIndex];
        require(coopSeat.isOpened, "seat is not opened");
        require(coopSeat.isExisted, "No hen in this seat");
        require(feedAmount > 0, "feed amount must be greater than 0");
        require(IToken(eggTokenAddress).balanceOf(sender) >= feedAmount, "Not enough egg token");

        HenCharacter memory hen = hensCatalog[coopSeat.id];
        uint256 foodIntake = coopSeat.foodIntake;
        uint256 maxFoodIntake = hen.maxFoodIntake;
        if(foodIntake >= maxFoodIntake) revert("Hen is full.");
        uint256 totalFoodIntake = foodIntake + feedAmount;

        if(totalFoodIntake > maxFoodIntake){
            totalFoodIntake = maxFoodIntake;
            feedAmount = maxFoodIntake - foodIntake;
        }
        coopSeats[target][seatIndex].foodIntake = totalFoodIntake;
        IToken(eggTokenAddress).burn(sender, feedAmount);

        if(sender != target){
            setAccountActionModifyBlock(sender, AccountAction.HelpOthers);
        }
        emit FeedHen(sender, target, seatIndex, feedAmount);
        setAccountActionModifyBlock(target, AccountAction.Feed);
    }

    function showHenHunger(address target) public view returns (FoodIntake[] memory){
        AccountInfo storage accountInfo = accountInfos[target];
        uint256 totalSeat = accountInfo.totalCoopSeats;
        isAccountJoinGame(target);
        FoodIntake[] memory foodIntakes = new FoodIntake[](totalSeat);
        uint i;
        for(i=0; i<totalSeat; i++){
            CoopSeat memory coopSeat = coopSeats[target][i];
            if(coopSeat.isExisted){
                HenCharacter memory hen = hensCatalog[coopSeat.id];
                foodIntakes[i] = FoodIntake(i, true, coopSeat.id, coopSeat.foodIntake, hen.maxFoodIntake);
            }else{
                foodIntakes[i] = FoodIntake(i, false, 0, 0, 0);
            }
        }
        return foodIntakes;
    }

    function getAllSeatStatus(bool _payIncentive) public returns (CoopSeat[] memory){
        AccountInfo storage accountInfo = accountInfos[msg.sender];
        uint256 totalSeat = accountInfo.totalCoopSeats;
        isAccountJoinGame(msg.sender);

        if(_payIncentive)
            payIncentive(msg.sender);
        
        CoopSeat[] memory coopSeatStatus = new CoopSeat[](totalSeat);
        uint i;
        for(i=0; i<totalSeat; i++){
            coopSeatStatus[i] = coopSeats[msg.sender][i];
        }
        return coopSeatStatus;
    }
}