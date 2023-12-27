pragma solidity ^0.8.17;

interface IGoldenCore{
    function setAccountModifyCurrentBlock(address account,GoldenCore.AccountAction action) external;
    function checkActivated(address account) external view returns (bool);
    function getAccountLastModifyBlockNumber(address account) external view returns(uint);
    function getCurrentBlockNumber() external view returns (uint256);
}

contract GoldenCore  {
    event AccountLastestAction(address indexed account, uint indexed blockNumber, AccountAction indexed action);
    enum AccountAction{
        FeedChicken,
        CleanCoop,
        AttackGame,
        OpenProtectShell,
        Shopping
    }

    struct AccountInfo{
        uint256 totalChickenSeat;
        uint256 totalTrashCan;
        mapping(uint256 => uint256) totalHen;
        mapping(uint256 => uint256) totalWatchDog;
        mapping(uint256 => uint256) totalProtectShell;
        uint256 lastActionBlockNumber;
        AccountAction lastAction;
    }

    address private constant adminAddress = 0x4ff1B1f7b28345eFC5e8f628A19e96c34696dbF0;
    mapping(address => AccountInfo) private accountInfos;
    uint constant BLOCKAMOUNT = 40_000; // around 7 days if creating a block take 15 second
    

    constructor() {
    }

    function setAccountModifyCurrentBlock(address account,AccountAction action) public {
        uint256 currentBlockNumber = getCurrentBlockNumber();
        accountInfos[account].lastActionBlockNumber = currentBlockNumber;
        accountInfos[account].lastAction = action;

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
}