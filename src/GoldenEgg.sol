pragma solidity ^0.8.21;
import "./ChickenCoop.sol";
import "./WatchDog.sol";
import "./Token.sol";

contract GoldenEgg is ChickenCoop, WatchDog {
    uint256 constant maxDurabilityOfProtectNumber = 10;
    uint256 constant unitTrashCanSpace = 100;
    uint256 constant maxPurchaseLimit = 10;
    struct Price {
        uint256 addProtectNumberEthPrice;
        uint256 removeProtectNumberEthPrice;
        uint256 trashCanEthPrice;
        uint256 seatEthPrice;
    }

    uint private priceModel;
    Price[] sellPrices;

    constructor() {
        sellPrices.push(
            Price({
                addProtectNumberEthPrice: 0.0003 ether,
                removeProtectNumberEthPrice: 0.0001 ether,
                trashCanEthPrice: 0.0001 ether,
                seatEthPrice: 0.0001 ether
            })
        );
    }
     /** startGame **/
    uint256 immutable initTrashCan = 1000;
    uint256 constant initCoopSeats = 1;
    uint256 constant initCoopSeatIndex = 0;
    uint256 constant initFirstHen = 0;
    uint256 constant initFirstWatchDog = 0;
    uint256 constant initProtectNumbers = 1;
    uint256 constant initProtectShellBlockAmount = 250;
    uint256 constant initDebtEggToken = 0;
    uint256 constant initEggTokenAmount = 30_000 ether;
    uint256 constant initShellTokenAmount = 300 ether;
    uint256 constant initDurabilityOfProtectNumber = 10;

    function startGame() public returns (uint256 initProtectNumber){
        require(accountInfos[msg.sender].lastActionBlockNumber == 0, "This address have joined Golden-Egg.");
        watchDogInfos[msg.sender].status = AttackStatus.Revert;
        setAccountActionModifyBlock(msg.sender, AccountAction.StartGame);

        accountInfos[msg.sender].totalCoopSeats = initCoopSeats;
        accountInfos[msg.sender].totalTrashCan = initTrashCan * IToken(litterTokenAddress).decimals();
        accountInfos[msg.sender].totalOwnHens[initFirstHen] = 1;
        accountInfos[msg.sender].totalOwnWatchDogs[initFirstWatchDog] = true;
        accountInfos[msg.sender].totalProtectNumbers = initProtectNumbers;
        initProtectNumber = (uint(keccak256(abi.encodePacked(block.timestamp, msg.sender))) % attackRange) + 1;
        accountInfos[msg.sender].protectNumbers[initProtectNumber] = initDurabilityOfProtectNumber;
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

    function setSellPrice(
        uint256 _addProtectNumberEthPrice,
        uint256 _removeProtectNumberEthPrice,
        uint256 _trashCanEthPrice,
        uint256 _seatEthPrice
    ) public onlyAdmin returns (uint) {
        sellPrices.push(
            Price({
                addProtectNumberEthPrice: _addProtectNumberEthPrice,
                removeProtectNumberEthPrice: _removeProtectNumberEthPrice,
                trashCanEthPrice: _trashCanEthPrice,
                seatEthPrice: _seatEthPrice
            })
        );
        return sellPrices.length - 1;
    }

    function changeSellPriceModel(uint model) public onlyAdmin {
        priceModel = model;
    }

    function getSellPrice() private view returns (Price memory) {
        return sellPrices[priceModel];
    }

    function buyHen(uint256 _henId, bool _payIncentive) public payable {
        isAccountJoinGame(msg.sender);
        checkHenExists(_henId);
        checkHenBillAndDelivered(msg.sender, _henId, msg.value);

        if (_payIncentive) {
            payIncentive(msg.sender);
        }
        setAccountActionModifyBlock(msg.sender, AccountAction.Shopping);
    }

    function buyWatchDog(uint256 _dogId, bool _payIncentive) public payable {
        isAccountJoinGame(msg.sender);
        checkDogExists(_dogId);

        checkDogBillAndDelivered(msg.sender, _dogId, msg.value);
        if (_payIncentive) {
            payIncentive(msg.sender);
        }

        setAccountActionModifyBlock(msg.sender, AccountAction.Shopping);
    }

    function addProtectNumber(uint256 _protectNumber, bool _payIncentive) public payable {
        isAccountJoinGame(msg.sender);
        require(accountInfos[msg.sender].totalProtectNumbers < maxTotalProtectNumbers, "You have reached the maximum number of purchases.");
        require(accountInfos[msg.sender].protectNumbers[_protectNumber] == 0, "You already bought this protect number.");
        require(!isAttackStatusPending(msg.sender), "You are being attacked.");
        require(_protectNumber > 0, "Protect number must be greater than 0.");

        bool success = checkBill(msg.sender, msg.value, getSellPrice().addProtectNumberEthPrice);
        if(success){
            accountInfos[msg.sender].totalProtectNumbers++;
            accountInfos[msg.sender].protectNumbers[_protectNumber] = maxDurabilityOfProtectNumber;
        }
        if (_payIncentive) {
            payIncentive(msg.sender);
        }

        setAccountActionModifyBlock(msg.sender, AccountAction.Shopping);
    }

    function removeProtectNumber(uint256 _protectNumber, bool _payIncentive) public payable {
        isAccountJoinGame(msg.sender);
        require(accountInfos[msg.sender].protectNumbers[_protectNumber] > 0, "You don't have this protect number.");
        require(!isAttackStatusPending(msg.sender), "You are being attacked.");
        require(_protectNumber > 0, "Protect number must be greater than 0.");

        bool success = checkBill(msg.sender, msg.value, getSellPrice().removeProtectNumberEthPrice);
        if(success){
            accountInfos[msg.sender].totalProtectNumbers--;
            accountInfos[msg.sender].protectNumbers[_protectNumber] = 0;
        }
        if (_payIncentive) {
            payIncentive(msg.sender);
        }

        setAccountActionModifyBlock(msg.sender, AccountAction.Shopping);
    }

    function buyTrashCan(uint256 amount,bool _payIncentive) public payable {
        isAccountJoinGame(msg.sender);
        require(amount > 0, "Amount must be greater than 0.");
        require(amount <= maxPurchaseLimit, "Amount must be less than maxPurchaseLimit.");
        require(!isAttackStatusPending(msg.sender), "You are being attacked.");


        bool success = checkBill(msg.sender, msg.value, getSellPrice().trashCanEthPrice * amount);
        if(success){
            accountInfos[msg.sender].totalTrashCan += amount * unitTrashCanSpace;
        }
        if(_payIncentive){
            payIncentive(msg.sender);
        }

        setAccountActionModifyBlock(msg.sender, AccountAction.Shopping);
    }
    
    function buyChickenCoopSeats(uint256 amount, bool _payIncentive) public payable {
        isAccountJoinGame(msg.sender);
        require(amount > 0, "Amount must be greater than 0.");
        require(amount <= maxPurchaseLimit, "Amount must be less than maxPurchaseLimit.");
        uint256 ownSeats = accountInfos[msg.sender].totalCoopSeats;
        require(amount + ownSeats <= maxCoopSeat, "You have reached the maximum number of purchases.");
        
        bool success = checkBill(msg.sender, msg.value, getSellPrice().seatEthPrice * amount);
        if(success){
            accountInfos[msg.sender].totalCoopSeats += amount;
        }
        if (_payIncentive) {
            payIncentive(msg.sender);
        }
        setAccountActionModifyBlock(msg.sender, AccountAction.Shopping);
    }

    function buyEggToken(bool _payIncentive) public payable {
        isAccountJoinGame(msg.sender);
        require(msg.value > 0, "ETH value must be greater than 0.");
        require(!isAttackStatusPending(msg.sender), "You are being attacked.");
        
        uint256 eggTokenAmount = msg.value * IToken(eggTokenAddress).getRatioOfEth();
        IToken(eggTokenAddress).mint(msg.sender, eggTokenAmount);
        if (_payIncentive) {
            payIncentive(msg.sender);
        }
        setAccountActionModifyBlock(msg.sender, AccountAction.Shopping);
    }

    function cleanLitter(bool _payIncentive) public payable {
        isAccountJoinGame(msg.sender);
        require(msg.value > 0, "ETH value must be greater than 0.");
        require(!isAttackStatusPending(msg.sender), "You are being attacked.");
        uint256 litterTokenAmount = msg.value * IToken(litterTokenAddress).getRatioOfEth();
        require(litterTokenAmount <= IToken(litterTokenAddress).balanceOf(msg.sender), "Invaild amount");

        IToken(litterTokenAddress).burn(msg.sender, litterTokenAmount);
        if (_payIncentive) {
            payIncentive(msg.sender);
        }
        setAccountActionModifyBlock(msg.sender, AccountAction.CleanCoop);
    }

    function buyProtectShell(bool _payIncentive) public payable {
        isAccountJoinGame(msg.sender);
        require(msg.value > 0, "ETH value must be greater than 0.");

        uint256 shellTokenAmount = msg.value * IToken(shellTokenAddress).getRatioOfEth();
        IToken(shellTokenAddress).mint(msg.sender, shellTokenAmount);
        if (_payIncentive) {
            payIncentive(msg.sender);
        }
        setAccountActionModifyBlock(msg.sender, AccountAction.Shopping);
    }

    function checkHenBillAndDelivered(address buyer, uint256 _henId, uint256 value) internal {
        HenCharacter memory hen = hensCatalog[_henId];
        require(hen.isOnSale, "This hen is not for sale.");
        require(
            hen.ethPrice > 0 || hen.eggPrice > 0,
            "This hen is not for sale."
        );
        uint256 maxOwnNumber = hen.purchaselimit;
        uint256 nowOwnNumber = accountInfos[buyer].totalOwnHens[_henId];
        require(
            nowOwnNumber < maxOwnNumber,
            "You have reached the maximum number of purchases."
        );

        if (value > 0) {
            require(hen.ethPrice > 0, "This hen is not for sale with ETH.");
            require(hen.ethPrice == value, "Incorrect ETH value.");
        } else {
            require(hen.eggPrice > 0, "This hen is not for sale with egg.");
            require(
                IToken(eggTokenAddress).balanceOf(buyer) >= hen.eggPrice,
                "Insufficient egg balance."
            );
            IToken(eggTokenAddress).burn(buyer, hen.eggPrice);
        }
        accountInfos[buyer].totalOwnHens[_henId]++;
    }

    function checkDogBillAndDelivered(address buyer, uint256 _dogId, uint256 value) internal {
        DogCharacter memory dog = dogsCatalog[_dogId];
        require(dog.isOnSale, "This dog is not for sale.");
        require(
            dog.ethPrice > 0 || dog.eggPrice > 0,
            "This dog is not for sale."
        );
        require(
            !accountInfos[buyer].totalOwnWatchDogs[_dogId],
            "You already bought this dog."
        );

        if (value > 0) {
            require(dog.ethPrice > 0, "This dog is not for sale with ETH.");
            require(dog.ethPrice == value, "Incorrect ETH value.");
        } else {
            require(dog.eggPrice > 0, "This dog is not for sale with egg.");
            require(
                IToken(eggTokenAddress).balanceOf(buyer) >= dog.eggPrice,
                "Insufficient egg balance."
            );
            IToken(eggTokenAddress).burn(buyer, dog.eggPrice);
        }
        accountInfos[buyer].totalOwnWatchDogs[_dogId] = true;
    }

    function checkBill(address buyer, uint256 value,uint ethPrice)internal returns (bool){
        if(value > 0){
            require(value == ethPrice, "Incorrect ETH value.");
        } else {
            uint eggTokenPrice = ethPrice * IToken(eggTokenAddress).getRatioOfEth();
            require(
                IToken(eggTokenAddress).balanceOf(buyer) >= eggTokenPrice,
                "Insufficient egg balance."
            );
            IToken(eggTokenAddress).burn(buyer, eggTokenPrice);
        }
        return true;
    }
    
}
