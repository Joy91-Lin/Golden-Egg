pragma solidity ^0.8.21;

import "./AdminControl.sol";

interface IGoldenTop{
    function checkActivated(address account) external view returns (bool);
    function getAccountLastModifyBlockNumber(address account) external view returns(uint);
    function getCurrentBlockNumber() external view returns (uint256);
    function isAccountJoinGame(address account) external view returns (bool);
    function getTotalTrashCanAmount(address account) external view returns (uint256);
}

interface IGoldenTopEvent{
    event AccountLastestAction(address indexed account, uint indexed blockNumber, GoldenTop.AccountAction indexed action);
}

interface IGoldenTopError{
    error TargetDoesNotJoinGameYet(address target);
}
 
contract GoldenTop is IGoldenTop, IGoldenTopEvent, IGoldenTopError, AdminControl {
    enum AccountAction{
        StartGame,
        HelpOthers,
        Feed,
        CleanCoop,
        AttackGame,
        OpenProtectShell,
        Shopping,
        PayIncentive,
        ExchangeHen,
        ExchangeWatchDog
    }

    struct AccountInfo{
        uint256 totalCoopSeats;
        uint256 totalTrashCan;
        mapping(uint256 => uint256) totalOwnHens;
        mapping(uint256 => uint256) hensInCoop;
        mapping(uint256 => bool) totalOwnWatchDogs;
        uint256 totalProtectNumbers;
        mapping(uint256 => uint256) protectNumbers;
        uint256 lastActionBlockNumber;
        uint256 lastPayIncentiveBlockNumber;
        uint256 lastCheckHenIndex;
        uint256 debtEggToken;
    }

    address private constant adminAddress = 0x4ff1B1f7b28345eFC5e8f628A19e96c34696dbF0;
    mapping(address => AccountInfo) accountInfos;
    uint constant BLOCKAMOUNT = 40_000; // around 7 days if creating a block take 15 second

    uint constant handlingFeeEther = 0.0001 ether;
    uint256 constant attackRange = 100;
    uint256 immutable maxTotalProtectNumbers = attackRange / 2;
    uint constant maxCoopSeat = 20;
    uint256 constant MANTISSA = 10 ** 18;

    address public eggTokenAddress;
    address public litterTokenAddress;
    address public shellTokenAddress;

    function setUpAddress(
        address _eggTokenAddress,
        address _litterTokenAddress,
        address _shellTokenAddress
    ) public onlyOwner{
        eggTokenAddress = _eggTokenAddress;
        litterTokenAddress = _litterTokenAddress;
        shellTokenAddress = _shellTokenAddress;
        allowers[_eggTokenAddress] = true;
        allowers[_litterTokenAddress] = true;
        allowers[_shellTokenAddress] = true;
        allowers[msg.sender] = true;
        allowers[address(this)] = true;
    }

    function setAccountActionModifyBlock(address account,AccountAction action) internal {
        uint256 currentBlockNumber = getCurrentBlockNumber();
        accountInfos[account].lastActionBlockNumber = currentBlockNumber;

        emit AccountLastestAction(account, currentBlockNumber, action);
    }

    function checkActivated(address account) public view returns (bool){
        uint accountLastModifyBlockNumber = accountInfos[account].lastActionBlockNumber;
        require(accountLastModifyBlockNumber == 0, "GoldenTop: This address haven't join Golden-Egg.");
        
        uint around7days = getCurrentBlockNumber() - BLOCKAMOUNT;
        if(accountLastModifyBlockNumber > around7days){
            return true;
        } else{
            return false;
        }
    }

    function getCurrentBlockNumber() public view returns (uint256){
        return block.number;
    }

    function isAccountJoinGame(address account) public view returns (bool){
        if(accountInfos[account].lastActionBlockNumber == 0)
            revert TargetDoesNotJoinGameYet(account);
        return true;
    }
    /** struct AccountInfo **/
    function getAccountTotalCoopSeats(address account) public view returns (uint256){
        return accountInfos[account].totalCoopSeats;
    }

    function getTotalTrashCanAmount(address account) public view returns (uint256){
        return accountInfos[account].totalTrashCan;
    }

    function getAccountTotalOwnHens(address account, uint256 henId) public view returns (uint256){
        return accountInfos[account].totalOwnHens[henId];
    }

    function getAccountHensInCoop(address account, uint256 henId) public view returns (uint256){
        return accountInfos[account].hensInCoop[henId];
    }

    function getAccountTotalOwnWatchDogs(address account, uint256 dogId) public view returns (bool){
        return accountInfos[account].totalOwnWatchDogs[dogId];
    }

    function getAccountTotalProtectNumbers(address account) public view returns (uint256){
        return accountInfos[account].totalProtectNumbers;
    }

    function getAccountProtectNumbers(address account, uint256 protectNumber) public view returns (uint256){
        return accountInfos[account].protectNumbers[protectNumber];
    }

    function getAccountLastModifyBlockNumber(address account) public view returns(uint){
        return accountInfos[account].lastActionBlockNumber;
    }

    function getAccountLastPayIncentiveBlockNumber(address account) public view returns(uint){
        return accountInfos[account].lastPayIncentiveBlockNumber;
    }

    function getAccountLastCheckHenIndex(address account) public view returns(uint){
        return accountInfos[account].lastCheckHenIndex;
    }

    function getAccountDebtEggToken(address account) public view returns(uint){
        return accountInfos[account].debtEggToken;
    }

}