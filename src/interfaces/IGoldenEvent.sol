pragma solidity ^0.8.21;

interface IGoldenEvent{
    /** BirthFactory **/
    event BirthHen(uint256 henId, bool isOnSale);
    event BirthDog(uint256 dogId, bool isOnSale);
    event HenSaleStatus(uint256 henId, bool isOnSale);
    event DogSaleStatus(uint256 dogId, bool isOnSale);
    /** ChickenCoop **/
    event PutUpHenToCoopSeats(address indexed sender, uint256 seatIndex, uint256 henId);
    event TakeDownHenFromCoopSeats(address indexed sender, uint256 seatIndex, uint256 henId);
    event FeedHen(address indexed sender, address indexed target, uint256 seatIndex, uint256 feedAmount);
    event OutOfGasLimit(uint256 gasUsed, uint256 startCheckBlockNumber, uint256 endCheckBlockNumber);
    event LayEGGs(uint256 seatIndex, uint256 eggToken, uint256 litterToken, uint256 protectShell);
    event TrashCanFull(uint256 seatIndex, uint256 henId, uint256 missingEggToken);
    /** WatchDog */
    event WatchDogExchange(address indexed owner, uint256 indexed id);
    event OpenProtectShell(address indexed owner, uint256 indexed startBlockNumber, uint256 indexed endBlockNumber);
}