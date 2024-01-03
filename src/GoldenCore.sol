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
    mapping(address => AccountInfo) internal accountInfos;
    uint constant BLOCKAMOUNT = 40_000; // around 7 days if creating a block take 15 second
    mapping(address => bool) internal allowers;

    uint constant handlingFeeEther = 0.0001 ether;
    uint256 constant attackRange = 100;
    uint256 immutable maxTotalProtectNumbers = attackRange / 2;
    uint constant maxCoopSeat = 20;

    address internal eggTokenAddress;
    address internal litterTokenAddress;
    address internal shellTokenAddress;
    address internal chickenCoopAddress;
    address internal watchDogAddress;
    address internal birthFactoryAddress;
    address internal goldenMarketAddress;

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

    function setUpAddress(
        address _eggTokenAddress,
        address _litterTokenAddress,
        address _shellTokenAddress,
        address _chickenCoopAddress,
        address _watchDogAddress,
        address _birthFactoryAddress,
        address _goldenMarketAddress
    ) public onlyOwner{
        eggTokenAddress = _eggTokenAddress;
        litterTokenAddress = _litterTokenAddress;
        shellTokenAddress = _shellTokenAddress;
        chickenCoopAddress = _chickenCoopAddress;
        watchDogAddress = _watchDogAddress;
        birthFactoryAddress = _birthFactoryAddress;
        allowers[_eggTokenAddress] = true;
        allowers[_litterTokenAddress] = true;
        allowers[_shellTokenAddress] = true;
        allowers[_chickenCoopAddress] = true;
        allowers[_watchDogAddress] = true;
        allowers[_birthFactoryAddress] = true;
        allowers[_goldenMarketAddress] = true;
    }

    // function startGame() public{
    //     require(accountInfos[msg.sender].lastActionBlockNumber == 0, "This address have joined Golden-Egg.");
    //     setAccountActionModifyBlock(msg.sender, AccountAction.StartGame);

    //     accountInfos[msg.sender].totalCoopSeats = 1;
    //     accountInfos[msg.sender].totalTrashCan = 50;
    //     accountInfos[msg.sender].totalOwnHens[1] = 1;
    //     accountInfos[msg.sender].totalOwnWatchDogs[1] = true;
    //     accountInfos[msg.sender].totalProtectNumbers = 1;
    //     uint256 initProtectNumber = (uint(keccak256(abi.encodePacked(block.timestamp, msg.sender))) % attackRange) + 1;
    //     accountInfos[msg.sender].protectNumbers[initProtectNumber] = 10;
    //     accountInfos[msg.sender].lastPayIncentiveBlockNumber = getCurrentBlockNumber();
    //     accountInfos[msg.sender].lastCheckHenIndex = 0;
    //     accountInfos[msg.sender].debtEggToken = 0;
        
    //     (bool success, bytes memory data) = eggTokenAddress.call(abi.encodeWithSignature("mint(address,uint256)", msg.sender, 30000));
    //     require(success, "mint egg token failed");
    //     (success,) = shellTokenAddress.call(abi.encodeWithSignature("mint(address,uint256)", msg.sender, 300));
    //     // put 1 hen into coop
    //     (success, data) = birthFactoryAddress.call(abi.encodeWithSignature("getMaxHenFoodIntake(uint256)", 1));
    //     require(success, "get max food intake failed");
    //     uint256 maxFoodIntake = abi.decode(data, (uint256));
    //     (success,) = chickenCoopAddress.call(abi.encodeWithSignature("putUpHen(uint,uint,bool,uint)", 
    //                         1, 1, true, maxFoodIntake));
    //     require(success, "put up hen failed");
    //     // put 1 watch dog
    //     (success,) = watchDogAddress.call(abi.encodeWithSignature("changeWatchDog(uint256,bool)", 1, true)); 
    //     require(success, "put up watch dog failed");
    //     // put protect shell for 250 blocks
    //     (success,) = watchDogAddress.call(abi.encodeWithSignature("openProtectShell(uint256)", 250));
    //     require(success, "open protect shell failed");

    // }

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