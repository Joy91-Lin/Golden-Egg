pragma solidity ^0.8.21;

import "chainlink/vrf/VRFV2WrapperConsumerBase.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./BirthFactory.sol";
import "./Token.sol";

interface IWatchDog {
    function isAttackStatusPending(address target) external view returns(bool);
}

contract WatchDog is BirthFactory{
    struct WatchDogInfo {
        uint256 id;
        uint256 protectShellStartBlockNumber;
        uint256 protectShellEndBlockNumber; 
        uint256 lastLaunchAttackRequestId; 
        uint256 lastBeAttackedRequestId;
        AttackStatus status;
    }

    
    enum AttackStatus {
        None,
        Pending,
        Completed,
        Revert
    }

    mapping(address => WatchDogInfo) watchDogInfos;
    uint256 constant maxOpenShellPeriod = 1000;
    uint256 constant cooldownPeriod = 100;

    uint256 constant targetShellRewardAmount = 100;

    function initProtectShellForBeginer(uint amount) internal {
        uint256 currentBlock = getCurrentBlockNumber();
        watchDogInfos[msg.sender].protectShellStartBlockNumber = currentBlock;
        watchDogInfos[msg.sender].protectShellEndBlockNumber = currentBlock + amount;
        watchDogInfos[msg.sender].status = AttackStatus.None;
        emit OpenProtectShell(msg.sender, currentBlock, currentBlock + amount);
    }
    // 替換看守犬
    function changeWatchDog(uint256 id, bool forceExchange) public payable {
        isAccountJoinGame(msg.sender);
        isAttackStatusPending(msg.sender);
        WatchDogInfo memory watchDog = watchDogInfos[msg.sender];
        if(!accountInfos[msg.sender].ownWatchDogs[id])
            revert InvalidDogId(id);
        checkFee(msg.sender, msg.value);

        if(!forceExchange){
            uint256 currentBlock = getCurrentBlockNumber();
            uint256 shellEndBlockNumber = watchDog.protectShellEndBlockNumber;
            if(shellEndBlockNumber >= currentBlock){
                revert FailedToChangeWatchDog(msg.sender, shellEndBlockNumber);
            }
        }
        watchDogInfos[msg.sender] = WatchDogInfo({
            id: id,
            protectShellStartBlockNumber: 0,
            protectShellEndBlockNumber: 0,
            lastLaunchAttackRequestId: 0,
            lastBeAttackedRequestId: 0,
            status: AttackStatus.None
        });
        emit WatchDogExchange(msg.sender, id);
        setAccountActionModifyBlock(msg.sender, AccountAction.ExchangeWatchDog);
    }
    // 檢查手續費
    function checkFee(address sender, uint value) internal {
        if(value > 0){
            if(value != handlingFeeEther) 
                revert InvalidPayment(sender, value);
        } else{
            uint256 handlingFeeEggToken = handlingFeeEther * IToken(eggTokenAddress).getRatioOfEth();
            if(IToken(eggTokenAddress).balanceOf(sender) < handlingFeeEggToken)
                revert InvalidPayment(sender, IToken(eggTokenAddress).balanceOf(sender));
            IToken(eggTokenAddress).burn(sender, handlingFeeEggToken);
        }
    }
    // 開啟保護罩
    function openProtectShell(uint amount) public payable{
        isAttackStatusPending(msg.sender);
        watchDogInfos[msg.sender].status = AttackStatus.Revert;
        uint balance = IToken(shellTokenAddress).balanceOf(msg.sender);
        // check input amount
        uint burnAmount = amount * 10 ** IToken(shellTokenAddress).decimals();
        if(burnAmount > balance || amount > maxOpenShellPeriod || amount < 20)
            revert InvalidInputNumber(msg.sender, amount);

        checkFee(msg.sender, msg.value);

        uint256 currentBlock = getCurrentBlockNumber();
        uint256 shellEndBlockNumber = watchDogInfos[msg.sender].protectShellEndBlockNumber;
        if(shellEndBlockNumber + cooldownPeriod >= currentBlock)
            revert FailedToOpenProtectShell(msg.sender);
        
        watchDogInfos[msg.sender].protectShellStartBlockNumber = currentBlock ;
        watchDogInfos[msg.sender].protectShellEndBlockNumber = currentBlock + amount;
        watchDogInfos[msg.sender].status = AttackStatus.None;

        IToken(shellTokenAddress).burn(msg.sender, burnAmount);

        emit OpenProtectShell(msg.sender, currentBlock, currentBlock + amount);
        setAccountActionModifyBlock(msg.sender, AccountAction.OpenProtectShell);
    }

    function isProtectShellOpen(address target) public view returns(bool){
        uint currentBlock = getCurrentBlockNumber();
        WatchDogInfo memory watchDog = watchDogInfos[target];
        if(currentBlock <= watchDog.protectShellEndBlockNumber + 10){
            return true;
        }
        return false;
    }
    // 農場是否可被攻擊
    function canAttack(address target) public view returns(bool){
        if(watchDogInfos[target].status != AttackStatus.Pending && watchDogInfos[target].status != AttackStatus.Revert)
            return true;
        return false;
    }
    // 確認是否正在被攻擊
    function isAttackStatusPending(address target) public view returns(bool){
        if(watchDogInfos[target].status == AttackStatus.Pending)
            revert AccountIsBeingAttacked(target);
        return false;
    }

    /** struct WatchDogInfo **/
    function getWatchDogInfo(address account) public view returns(WatchDogInfo memory){
        return watchDogInfos[account];
    }
    // 設定攻擊開始參數
    function setForAttackGameStart(uint256 requestId, address attacker, address target) public {
        onlyAdmin();
        watchDogInfos[target].status = AttackStatus.Pending;
        watchDogInfos[attacker].lastLaunchAttackRequestId = requestId;
        watchDogInfos[target].lastBeAttackedRequestId = requestId;
    }
    // 設定攻擊結束參數
    function setForAttackGameEnd(address attacker, address target, bool attackSuccess, uint attackNumber, uint targetDebt)public {
        onlyAdmin();
        watchDogInfos[target].status = AttackStatus.Completed;
        if(attackSuccess){
            uint256 currentBlock = getCurrentBlockNumber();
            watchDogInfos[target].protectShellStartBlockNumber = currentBlock;
            watchDogInfos[target].protectShellEndBlockNumber = currentBlock + targetShellRewardAmount;
            accountInfos[target].debtEggToken += targetDebt;
        } else{
            accountInfos[target].durabilityOfProtectNumber[attackNumber]--;
            if(accountInfos[target].durabilityOfProtectNumber[attackNumber] == 0){
                accountInfos[target].totalProtectNumbers--;
            }
        }
        setAccountActionModifyBlock(attacker, AccountAction.AttackGame);
    }
}