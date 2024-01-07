pragma solidity ^0.8.21;

interface IGoldenError{
    /** AdminControl **/
    error SenderMustBeAdmin(address caller);
    /** BirthFactory **/
    error InvalidHenId(uint256 henId);
    error InvalidDogId(uint256 dogId);
    /** ChickenCoop */
    error FailedToPutUpHen(address target, uint256 henId, uint256 seatIndex, bool isExisted);
    error FailedToTakeDownHen(address target, uint256 henId, uint256 seatIndex);
    error InvalidSeatIndex(address caller, uint256 seatIndex);
    error DonotHaveHenInSeat(address caller, uint256 seatIndex, uint256 henId);
    error InvalidExchangeFee(address caller, uint256 value);
    error InsufficientAmount(address caller, uint256 amount);
    error HenIsFull(address caller, uint256 seatIndex, uint256 henId);
    /** GoldenTop **/
    error TargetDoesNotJoinGameYet(address target);
    /** GoldenEgg **/
    error FailedToAddProtectNumber(address target, uint256 protectNumber);
    error FailedToRemoveProtectNumber(address target, uint256 protectNumber);
    error InvalidInputNumber(address target, uint256 amount);
    error InvalidAccount(address target);
    error InvalidPayment(address target, uint256 amount);
    error FailedToBuyHen(address target, uint256 henId);
    error ReachedLimit(address target, uint256 purchaseLimit);
    error FailedToBuyWatchDog(address target, uint256 dogId);
    error FailedtakeOutProtocolIncome(address sender, address target, uint256 amount);
    /** WatchDog **/
    error AccountIsBeingAttacked(address target);
    error FailedToChangeWatchDog(address target, uint256 shellEndBlock);
    error FailedToOpenProtectShell(address target);
}