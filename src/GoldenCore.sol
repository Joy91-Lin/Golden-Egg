pragma solidity ^0.8.21;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

interface IGoldenCore{
    function checkActivated(address account) external view returns (bool);
    function getAccountLastModifyBlockNumber(address account) external view returns(uint);
    function getCurrentBlockNumber() external view returns (uint256);
    function isAccountJoinGame(address account) external view returns (bool);
    function getTotalTrashCanAmount(address account) external view returns (uint256);
}

interface IGoldenCoreEvent{
    event AccountLastestAction(address indexed account, uint indexed blockNumber, GoldenCore.AccountAction indexed action);
}

interface IGoldenCoreError{
    error SenderMustBeAdmin(address caller);
    error TargetDoesNotJoinGameYet(address target);
}
 
contract GoldenCore is Ownable, IGoldenCore, IGoldenCoreEvent, IGoldenCoreError {
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
        mapping(uint256 => bool) totalOwnWatchDogs;
        uint256 totalProtectNumbers;
        mapping(uint256 => bool) protectNumbers;
        mapping(uint256 => uint256) hensInCoop;
        uint256 lastActionBlockNumber;
        uint256 lastPayIncentiveBlockNumber;
        uint256 lastCheckHenIndex;
        uint256 debtEggToken;
    }

    address private constant adminAddress = 0x4ff1B1f7b28345eFC5e8f628A19e96c34696dbF0;
    mapping(address => AccountInfo) internal accountInfos;
    uint constant BLOCKAMOUNT = 40_000; // around 7 days if creating a block take 15 second
    mapping(address => bool) internal allowers;

    uint constant handlingFeeEggToken = 1000;
    uint constant handlingFeeEther = 0.0001 ether;
    uint256 constant attackRange = 100;
    uint256 immutable maxTotalProtectNumbers = attackRange / 2;

    constructor() Ownable(msg.sender){
        allowers[msg.sender] = true;
        allowers[address(this)] = true;
    }

    modifier onlyAdmin() {
        if(allowers[msg.sender])
            _;
        else
            revert SenderMustBeAdmin(msg.sender);
    }

    function addAdmin(address account) public onlyOwner {
        allowers[account] = true;
    }

    function removeAdmin(address account) public onlyOwner {
        allowers[account] = false;
    }

    function isAdmin(address account) public view returns (bool){
        return allowers[account];
    }

    function startGame() public{
        
    }

    function setAccountActionModifyBlock(address account,AccountAction action) internal {
        uint256 currentBlockNumber = getCurrentBlockNumber();
        accountInfos[account].lastActionBlockNumber = currentBlockNumber;

        emit AccountLastestAction(account, currentBlockNumber, action);
    }

    function checkActivated(address account) public view returns (bool){
        uint accountLastModifyBlockNumber = accountInfos[account].lastActionBlockNumber;
        require(accountLastModifyBlockNumber == 0, "This address haven't join Golden-Egg.");
        
        uint around7days = getCurrentBlockNumber() - BLOCKAMOUNT;
        if(accountLastModifyBlockNumber > around7days){
            return true;
        } else{
            return false;
        }
    }

    function getAccountLastModifyBlockNumber(address account) public view returns(uint){
        return accountInfos[account].lastActionBlockNumber;
    }

    function getCurrentBlockNumber() public view returns (uint256){
        return block.number;
    }

    function isAccountJoinGame(address account) public view returns (bool){
        if(accountInfos[account].lastActionBlockNumber == 0)
            revert TargetDoesNotJoinGameYet(account);
        return true;
    }

    function getTotalTrashCanAmount(address account) public view returns (uint256){
        return accountInfos[account].totalTrashCan;
    }
}