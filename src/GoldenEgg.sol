pragma solidity ^0.8.21;
import "./ChickenCoop.sol";
import "./WatchDog.sol";
import "./Token.sol";

contract GoldenEgg is ChickenCoop, WatchDog {

    uint256 public constant maxDurabilityOfProtectNumber = 10;
    uint256 public constant unitTrashCanSpace = 10 ** 18;
    uint256 public constant maxPurchaseLimit = 10;
    uint256 public constant maxTransFerTokenAmount = 10_000 * 10 ** 18;
    struct Price {
        uint256 addProtectNumberEthPrice;
        uint256 removeProtectNumberEthPrice;
        uint256 trashCanEthPrice;
        uint256 seatEthPrice;
        uint256 transferTokenFeeEthPrice;
    }

    uint private priceModel;
    Price[] sellPrices;

     /** startGame **/
    uint256 public constant initTrashCan = 1000;
    uint256 public constant initCoopSeats = 1;
    uint256 public constant initCoopSeatIndex = 0;
    uint256 public constant initFirstHen = 0;
    uint256 public constant initFirstWatchDog = 0;
    uint256 public constant initProtectNumbers = 1;
    uint256 public constant initProtectShellBlockAmount = 250;
    uint256 public constant initDebtEggToken = 0;
    uint256 public constant initEggTokenAmount = 3_000 ether;
    uint256 public constant initShellTokenAmount = 300 ether;

    constructor() {
        sellPrices.push(
            Price({
                addProtectNumberEthPrice: 0.0003 ether,
                removeProtectNumberEthPrice: 0.0001 ether,
                trashCanEthPrice: 0.0001 ether,
                seatEthPrice: 0.0001 ether,
                transferTokenFeeEthPrice: 0.0001 ether
            })
        );
    }
    // 玩家開始遊戲
    function startGame() public returns (uint256 initProtectNumber){
        if(accountInfos[msg.sender].lastActionBlockNumber > 0 || msg.sender == address(0))
            revert InvalidAccount(msg.sender);
        watchDogInfos[msg.sender].status = AttackStatus.Revert;
        setAccountActionModifyBlock(msg.sender, AccountAction.StartGame);

        accountInfos[msg.sender].totalCoopSeats = initCoopSeats;
        accountInfos[msg.sender].totalTrashCan = initTrashCan * 10 ** IToken(litterTokenAddress).decimals();
        accountInfos[msg.sender].ownHens[initFirstHen] = 1;
        accountInfos[msg.sender].ownWatchDogs[initFirstWatchDog] = true;
        accountInfos[msg.sender].totalProtectNumbers = initProtectNumbers;
        initProtectNumber = (uint(keccak256(abi.encodePacked(block.timestamp, msg.sender))) % attackRange) + 1;
        accountInfos[msg.sender].durabilityOfProtectNumber[initProtectNumber] = maxDurabilityOfProtectNumber;
        accountInfos[msg.sender].lastPayIncentiveBlockNumber = getCurrentBlockNumber();
        accountInfos[msg.sender].lastCheckHenIndex = 0;
        accountInfos[msg.sender].debtEggToken = initDebtEggToken;

        coopSeats[msg.sender][initCoopSeatIndex].isOpened = true;

        IToken(eggTokenAddress).mint(msg.sender, initEggTokenAmount);
        IToken(shellTokenAddress).mint(msg.sender, initShellTokenAmount);
        uint fullFirstHen = hensCatalog[initFirstHen].maxFoodIntake;
        putUpHen(initCoopSeatIndex, initFirstHen, true, fullFirstHen);
        changeWatchDog(initFirstWatchDog, true);
        initProtectShellForBeginer(initProtectShellBlockAmount);
    }
    // 設定價格
    function setSellPrice(
        uint256 _addProtectNumberEthPrice,
        uint256 _removeProtectNumberEthPrice,
        uint256 _trashCanEthPrice,
        uint256 _seatEthPrice,
        uint256 _transferTokenFeeEthPrice
    ) public returns (uint) {
        onlyAdmin();
        sellPrices.push(
            Price({
                addProtectNumberEthPrice: _addProtectNumberEthPrice,
                removeProtectNumberEthPrice: _removeProtectNumberEthPrice,
                trashCanEthPrice: _trashCanEthPrice,
                seatEthPrice: _seatEthPrice,
                transferTokenFeeEthPrice: _transferTokenFeeEthPrice
            })
        );
        return sellPrices.length - 1;
    }
    // 設定價格模式
    function changeSellPriceModel(uint model) public {
        onlyAdmin();
        priceModel = model;
    }
    // 取得價格
    function getSellPrice() public view returns (Price memory) {
        return sellPrices[priceModel];
    }
    // 購買雞
    function buyHen(uint256 _henId, bool _payIncentive) public payable {
        isAccountJoinGame(msg.sender);
        checkHenExists(_henId);
        checkHenBillAndDelivered(msg.sender, _henId, msg.value);

        if (_payIncentive) {
            payIncentive(msg.sender);
        }
        setAccountActionModifyBlock(msg.sender, AccountAction.Shopping);
    }
    // 購買看門狗
    function buyWatchDog(uint256 _dogId, bool _payIncentive) public payable {
        isAccountJoinGame(msg.sender);
        checkDogExists(_dogId);

        checkDogBillAndDelivered(msg.sender, _dogId, msg.value);
        if (_payIncentive) {
            payIncentive(msg.sender);
        }

        setAccountActionModifyBlock(msg.sender, AccountAction.Shopping);
    }
    // 購買保護數字
    function addProtectNumber(uint256 _protectNumber, bool _payIncentive) public payable {
        isAccountJoinGame(msg.sender);
        isAttackStatusPending(msg.sender);
        if(accountInfos[msg.sender].totalProtectNumbers >= maxTotalProtectNumbers||
            accountInfos[msg.sender].durabilityOfProtectNumber[_protectNumber] > 0)
            revert FailedToAddProtectNumber(msg.sender, _protectNumber);
        if(_protectNumber == 0 || _protectNumber > attackRange)
            revert InvalidInputNumber(msg.sender, _protectNumber);

        bool success = checkBill(msg.sender, msg.value, getSellPrice().addProtectNumberEthPrice);
        if(success){
            accountInfos[msg.sender].totalProtectNumbers++;
            accountInfos[msg.sender].durabilityOfProtectNumber[_protectNumber] = maxDurabilityOfProtectNumber;
        }
        if (_payIncentive) {
            payIncentive(msg.sender);
        }

        setAccountActionModifyBlock(msg.sender, AccountAction.Shopping);
    }
    // 移除保護數字
    function removeProtectNumber(uint256 _protectNumber, bool _payIncentive) public payable {
        isAccountJoinGame(msg.sender);
        isAttackStatusPending(msg.sender);
        if(accountInfos[msg.sender].durabilityOfProtectNumber[_protectNumber] == 0)
            revert FailedToRemoveProtectNumber(msg.sender, _protectNumber);
        if(_protectNumber == 0 || _protectNumber > attackRange)
            revert InvalidInputNumber(msg.sender, _protectNumber);

        bool success = checkBill(msg.sender, msg.value, getSellPrice().removeProtectNumberEthPrice);
        if(success){
            accountInfos[msg.sender].totalProtectNumbers--;
            accountInfos[msg.sender].durabilityOfProtectNumber[_protectNumber] = 0;
        }
        if (_payIncentive) {
            payIncentive(msg.sender);
        }

        setAccountActionModifyBlock(msg.sender, AccountAction.Shopping);
    }
    // 購買垃圾桶容量
    function buyTrashCan(uint256 amount,bool _payIncentive) public payable {
        isAccountJoinGame(msg.sender);
        if(amount == 0) 
            revert InvalidInputNumber(msg.sender, amount);
        if(amount > maxPurchaseLimit)
            revert ReachedLimit(msg.sender, maxPurchaseLimit);
        isAttackStatusPending(msg.sender);


        bool success = checkBill(msg.sender, msg.value, getSellPrice().trashCanEthPrice * amount);
        if(success){
            accountInfos[msg.sender].totalTrashCan += amount * unitTrashCanSpace;
        }
        if(_payIncentive){
            payIncentive(msg.sender);
        }

        setAccountActionModifyBlock(msg.sender, AccountAction.Shopping);
    }
    // 購買雞舍座位
    function buyChickenCoopSeats(uint256 amount, bool _payIncentive) public payable {
        isAccountJoinGame(msg.sender);
        uint256 ownSeats = accountInfos[msg.sender].totalCoopSeats;
        if(amount == 0) 
            revert InvalidInputNumber(msg.sender, amount);
        if(amount > maxPurchaseLimit || amount + ownSeats > maxCoopSeat)
            revert ReachedLimit(msg.sender, maxPurchaseLimit);
        
        bool success = checkBill(msg.sender, msg.value, getSellPrice().seatEthPrice * amount);
        if(success){
            for(uint256 i = ownSeats; i < ownSeats + amount; i++){
                coopSeats[msg.sender][i].isOpened = true;
            }
            accountInfos[msg.sender].totalCoopSeats = ownSeats + amount;
            
        }
        if (_payIncentive) {
            payIncentive(msg.sender);
        }
        setAccountActionModifyBlock(msg.sender, AccountAction.Shopping);
    }
    // 購買EggToken
    function buyEggToken(bool _payIncentive) public payable {
        isAccountJoinGame(msg.sender);
        if(msg.value == 0)
            revert InvalidPayment(msg.sender, msg.value);
        isAttackStatusPending(msg.sender);
        
        uint256 eggTokenAmount = msg.value * IToken(eggTokenAddress).getRatioOfEth();
        IToken(eggTokenAddress).mint(msg.sender, eggTokenAmount);
        if (_payIncentive) {
            payIncentive(msg.sender);
        }
        setAccountActionModifyBlock(msg.sender, AccountAction.Shopping);
    }

    // 清理LitterToken
    function cleanLitter(bool _payIncentive) public payable {
        isAccountJoinGame(msg.sender);
        isAttackStatusPending(msg.sender);
        if(msg.value == 0)
            revert InvalidPayment(msg.sender, msg.value);
        uint256 litterTokenAmount = msg.value * IToken(litterTokenAddress).getRatioOfEth();
        if(litterTokenAmount > IToken(litterTokenAddress).balanceOf(msg.sender))
            revert InvalidInputNumber(msg.sender, litterTokenAmount);

        IToken(litterTokenAddress).burn(msg.sender, litterTokenAmount);
        if (_payIncentive) {
            payIncentive(msg.sender);
        }
        setAccountActionModifyBlock(msg.sender, AccountAction.CleanCoop);
    }
    // 購買ShellToken
    function buyProtectShell(bool _payIncentive) public payable {
        isAccountJoinGame(msg.sender);
        if(msg.value == 0)
            revert InvalidPayment(msg.sender, msg.value);

        uint256 shellTokenAmount = msg.value * IToken(shellTokenAddress).getRatioOfEth();
        IToken(shellTokenAddress).mint(msg.sender, shellTokenAmount);
        if (_payIncentive) {
            payIncentive(msg.sender);
        }
        setAccountActionModifyBlock(msg.sender, AccountAction.Shopping);
    }
    // 傳遞EggToken
    function transferEggToken(address to, uint256 amount, bool _payIncentive) public payable {
        isAccountJoinGame(msg.sender);
        isAccountJoinGame(to);
        if(amount == 0)
            revert InvalidInputNumber(msg.sender, amount);
        if(amount > maxTransFerTokenAmount)
            revert ReachedLimit(msg.sender, maxTransFerTokenAmount);

        bool success = checkBill(msg.sender, msg.value, getSellPrice().transferTokenFeeEthPrice);
        if(success){
            if(IToken(eggTokenAddress).balanceOf(msg.sender) < amount)
                revert InvalidInputNumber(msg.sender, amount);
            IToken(eggTokenAddress).transferFrom(msg.sender, to, amount);
        }
        if (_payIncentive) {
            payIncentive(msg.sender);
        }
        setAccountActionModifyBlock(msg.sender, AccountAction.TransferToken);
    }
    // 傳遞ShellToken
    function transferShellToken(address to, uint256 amount, bool _payIncentive) public payable {
        isAccountJoinGame(msg.sender);
        isAccountJoinGame(to);
        if(amount == 0)
            revert InvalidInputNumber(msg.sender, amount);
        if(amount > maxTransFerTokenAmount)
            revert ReachedLimit(msg.sender, maxTransFerTokenAmount);

        bool success = checkBill(msg.sender, msg.value, getSellPrice().transferTokenFeeEthPrice);
        if(success){
            if(IToken(shellTokenAddress).balanceOf(msg.sender) < amount)
                revert InvalidInputNumber(msg.sender, amount);

            IToken(shellTokenAddress).transferFrom(msg.sender, to, amount);
        }
        if (_payIncentive) {
            payIncentive(msg.sender);
        }
        setAccountActionModifyBlock(msg.sender, AccountAction.TransferToken);
    }
    // 檢查購買雞的帳單並交付
    function checkHenBillAndDelivered(address buyer, uint256 _henId, uint256 value) internal {
        HenCharacter memory hen = hensCatalog[_henId];
        if(!hen.isOnSale || (hen.ethPrice == 0 && hen.eggPrice == 0))
            revert FailedToBuyHen(buyer, _henId);
        uint256 maxOwnNumber = hen.purchaselimit;
        uint256 nowOwnNumber = accountInfos[buyer].ownHens[_henId];
        if(nowOwnNumber + 1 >= maxOwnNumber)
            revert ReachedLimit(buyer, maxOwnNumber);
        

        if (value > 0) {
            if(hen.ethPrice == 0)
                revert FailedToBuyHen(buyer, _henId);
            if(hen.ethPrice != value)
                revert InvalidPayment(buyer, value);
        } else {
            if(hen.eggPrice == 0)
                revert FailedToBuyHen(buyer, _henId);
            if(IToken(eggTokenAddress).balanceOf(buyer) < hen.eggPrice)
                revert InvalidPayment(buyer, IToken(eggTokenAddress).balanceOf(buyer));
            IToken(eggTokenAddress).burn(buyer, hen.eggPrice);
        }
        accountInfos[buyer].ownHens[_henId]++;
    }
    // 檢查購買狗的帳單並交付
    function checkDogBillAndDelivered(address buyer, uint256 _dogId, uint256 value) internal {
        DogCharacter memory dog = dogsCatalog[_dogId];
        if(!dog.isOnSale || (dog.ethPrice == 0 && dog.eggPrice == 0))
            revert FailedToBuyWatchDog(buyer, _dogId);
        if(accountInfos[buyer].ownWatchDogs[_dogId])
            revert ReachedLimit(buyer, 1);

        if (value > 0) {
            if(dog.ethPrice == 0)
                revert FailedToBuyWatchDog(buyer, _dogId);
            if(dog.ethPrice != value)
                revert InvalidPayment(buyer, value);
        } else {
            if(dog.eggPrice == 0)
                revert FailedToBuyWatchDog(buyer, _dogId);
            if(IToken(eggTokenAddress).balanceOf(buyer) < dog.eggPrice)
                revert InvalidPayment(buyer, IToken(eggTokenAddress).balanceOf(buyer));
            IToken(eggTokenAddress).burn(buyer, dog.eggPrice);
        }
        accountInfos[buyer].ownWatchDogs[_dogId] = true;
    }
    // 檢查帳單
    function checkBill(address buyer, uint256 value,uint ethPrice)internal returns (bool){
        if(value > 0){
            if(value != ethPrice)
                revert InvalidPayment(buyer, value);
        } else {
            uint eggTokenPrice = ethPrice * IToken(eggTokenAddress).getRatioOfEth();
            if(IToken(eggTokenAddress).balanceOf(buyer) < eggTokenPrice)
                revert InvalidPayment(buyer, IToken(eggTokenAddress).balanceOf(buyer));
            IToken(eggTokenAddress).burn(buyer, eggTokenPrice);
        }
        return true;
    }
    
    function takeOutIncome() public {
        onlyContractOwner();
        (bool success,) = owner().call{value: address(this).balance}("");
        if(!success)
            revert FailedtakeOutProtocolIncome(address(this), owner(), address(this).balance);
    }
    
    function takeOutIncome(uint etherBalance) public {
        onlyContractOwner();
        (bool success,) = owner().call{value: etherBalance}("");
        if(!success)
            revert FailedtakeOutProtocolIncome(address(this), owner(), etherBalance);
    }

    function getContractBalance() public view returns(uint256){
        onlyContractOwner();
        return address(this).balance;
    }

}
