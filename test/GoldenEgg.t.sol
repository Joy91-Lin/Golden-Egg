pragma solidity ^0.8.21;
import { console2,Test } from "forge-std/Test.sol";
import {GoldenEggScript} from "../script/GoldenEgg.s.sol";
import {GoldenEgg} from "../src/GoldenEgg.sol";


contract GoldenEggTest is Test, GoldenEggScript {
    address user1 = makeAddr("user1");
    address user2 = makeAddr("user2");
    address nonJoinGame = makeAddr("nonJoinGame");

    /** AdminControl **/
    bytes4 selectorSenderMustBeAdmin = bytes4(keccak256("SenderMustBeAdmin(address)"));
    /** BirthFactory **/
    bytes4 selectorInvalidHenId = bytes4(keccak256("InvalidHenId(uint256)"));
    bytes4 selectorInvalidDogId = bytes4(keccak256("InvalidDogId(uint256)"));
    /** ChickenCoop */
    bytes4 selectorFailedToPutUpHen = bytes4(keccak256("FailedToPutUpHen(address,uint256,uint256,bool)"));
    bytes4 selectorFailedToTakeDownHen = bytes4(keccak256("FailedToTakeDownHen(address,uint256,uint256)"));
    bytes4 selectorInvalidSeatIndex = bytes4(keccak256("InvalidSeatIndex(address,uint256)"));
    bytes4 selectorDonotHaveHenInSeat = bytes4(keccak256("DonotHaveHenInSeat(address,uint256,uint256)"));
    bytes4 selectorInvalidExchangeFee = bytes4(keccak256("InvalidExchangeFee(address,uint256)"));
    bytes4 selectorInsufficientAmount = bytes4(keccak256("InsufficientAmount(address,uint256)"));
    bytes4 selectorHenIsFull = bytes4(keccak256("HenIsFull(address,uint256,uint256)"));
    /** GoldenTop **/
    bytes4 selectorTargetDoesNotJoinGameYet = bytes4(keccak256("TargetDoesNotJoinGameYet(address)"));
    /** GoldenEgg **/
    bytes4 selectorFailedToAddProtectNumber = bytes4(keccak256("FailedToAddProtectNumber(address,uint256)"));
    bytes4 selectorFailedToRemoveProtectNumber = bytes4(keccak256("FailedToRemoveProtectNumber(address,uint256)"));
    bytes4 selectorInvalidInputNumber = bytes4(keccak256("InvalidInputNumber(address,uint256)"));
    bytes4 selectorInvalidAccount = bytes4(keccak256("InvalidAccount(address)"));
    bytes4 selectorInvalidPayment = bytes4(keccak256("InvalidPayment(address,uint256)"));
    bytes4 selectorFailedToBuyHen = bytes4(keccak256("FailedToBuyHen(address,uint256)"));
    bytes4 selectorReachedLimit = bytes4(keccak256("ReachedLimit(address,uint256)"));
    bytes4 selectorFailedToBuyWatchDog = bytes4(keccak256("FailedToBuyWatchDog(address,uint256)"));
    bytes4 selectorFailedtakeOutProtocolIncome = bytes4(keccak256("FailedtakeOutProtocolIncome(address,address,uint256)"));
    /** WatchDog **/
    bytes4 selectorAccountIsBeingAttacked = bytes4(keccak256("AccountIsBeingAttacked(address)"));
    bytes4 selectorFailedToChangeWatchDog = bytes4(keccak256("FailedToChangeWatchDog(address,uint256)"));
    bytes4 selectorFailedToOpenProtectShell = bytes4(keccak256("FailedToOpenProtectShell(address)"));

    enum AttackStatus {
        None,
        Pending,
        Completed,
        Revert
    }

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
    
    function setUp() public {
        run();
        vm.roll(1000);
        deal(user1, 100 ether);
        deal(user1, 100 ether);

        // check enter game
        vm.prank(user1);
        uint initProtectNumber1 = goldenEgg.startGame();
        assertEq(goldenEgg.maxDurabilityOfProtectNumber(), goldenEgg.getAccountProtectNumberDurability(user1, initProtectNumber1));
        assertEq(0, goldenEgg.getAccountProtectNumberDurability(user1, initProtectNumber1-1));

        vm.prank(user2);
        uint initProtectNumber2 = goldenEgg.startGame();
        assertEq(goldenEgg.maxDurabilityOfProtectNumber(), goldenEgg.getAccountProtectNumberDurability(user2, initProtectNumber2));
        assertEq(0, goldenEgg.getAccountProtectNumberDurability(user2, initProtectNumber2-1));
    }

    function test_ownerAdmin()public{
        assertEq(deployContract, goldenEgg.owner());
        assertTrue(goldenEgg.isAdmin(deployContract));
        assertTrue(goldenEgg.isAdmin(address(goldenEgg)));
        assertTrue(goldenEgg.isAdmin(address(attackGame)));

        assertEq(deployContract, eggToken.owner());
        assertTrue(eggToken.isAdmin(address(goldenEgg)));
        assertTrue(eggToken.isAdmin(address(attackGame)));

        assertEq(deployContract, litterToken.owner());
        assertTrue(litterToken.isAdmin(address(goldenEgg)));
        assertTrue(litterToken.isAdmin(address(attackGame)));

        assertEq(deployContract, shellToken.owner());
        assertTrue(shellToken.isAdmin(address(goldenEgg)));
        assertTrue(shellToken.isAdmin(address(attackGame)));
    }

    function test_entryGameInitValue()public{
        vm.startPrank(user1);
        assertEq(goldenEgg.getCoopSeatInfo()[0].isOpened, true);
        assertEq(goldenEgg.getCoopSeatInfo()[0].isExisted, true);
        uint256 initFirstHen = goldenEgg.initFirstHen();
        assertEq(goldenEgg.getCoopSeatInfo()[0].id, initFirstHen);
        assertEq(goldenEgg.getCoopSeatInfo()[0].layingTimes, 0);
        assertEq(goldenEgg.getCoopSeatInfo()[0].protectShellCount, 0);
        assertEq(goldenEgg.getCoopSeatInfo()[0].foodIntake, goldenEgg.getHenCatalog(initFirstHen).maxFoodIntake);
        assertEq(goldenEgg.getCoopSeatInfo()[0].layingLeftCycle, goldenEgg.getHenCatalog(initFirstHen).layingCycle);
        assertEq(goldenEgg.getCoopSeatInfo()[0].lastCheckBlockNumberPerSeat, block.number);
        assertEq(uint(AttackStatus.None), uint(goldenEgg.getWatchDogInfo(user1).status));
        vm.stopPrank();
    }

    function test_checkUserJoinGame()public{
        assertTrue(goldenEgg.isAccountJoinGame(user1));
        assertTrue(goldenEgg.isAccountJoinGame(user2));
        vm.expectRevert(abi.encodeWithSelector(selectorTargetDoesNotJoinGameYet, nonJoinGame));
        goldenEgg.isAccountJoinGame(nonJoinGame);
    }

    function test_feedHen()public{
        vm.startPrank(user1);
        // can't feed hen if hen is full
        vm.expectRevert(abi.encodeWithSelector(selectorHenIsFull, user1, 0, goldenEgg.getCoopSeatInfo()[0].id));
        goldenEgg.feedOwnHen(0, 100);

        // can't feed hen if target don't have that seat
        vm.expectRevert(abi.encodeWithSelector(selectorInvalidSeatIndex, user1, 1));
        goldenEgg.feedOwnHen(1, 100);

        // can't feed hen if target don't have hen in that seat
        goldenEgg.buyChickenCoopSeats{value:goldenEgg.getSellPrice().seatEthPrice}(1, false);
        vm.expectRevert(abi.encodeWithSelector(selectorDonotHaveHenInSeat, user1, 1, goldenEgg.getCoopSeatInfo()[1].id));
        goldenEgg.feedOwnHen(1, 100);

        // can't help feed hen if hen is full
        vm.expectRevert(abi.encodeWithSelector(selectorHenIsFull, user2, 0, goldenEgg.getHenHunger(user2)[0].id));
        goldenEgg.helpFeedHen(user2, 0, 100);

        // can't help feed hen if target don't have that seat
        vm.expectRevert(abi.encodeWithSelector(selectorInvalidSeatIndex, user2, 1));
        goldenEgg.helpFeedHen(user2, 1, 100);

        // digest some food
        vm.roll(block.number + 1);
        uint256 preFoodIntake = goldenEgg.getCoopSeatInfo()[0].foodIntake;
        uint consumeFood = goldenEgg.getHenCatalog(goldenEgg.getCoopSeatInfo()[0].id).consumeFoodForOneBlock * 1;
        goldenEgg.payIncentive(user1);
        uint256 postFoodIntake = goldenEgg.getCoopSeatInfo()[0].foodIntake;
        assertEq(preFoodIntake - postFoodIntake, consumeFood);
        vm.stopPrank();

        // feed hen
        vm.startPrank(user1);
        uint256 preBalance = eggToken.balanceOf(user1);
        goldenEgg.feedOwnHen(0, 1 * 10 ** eggToken.decimals());   
        assertEq(postFoodIntake + 1 * 10 ** eggToken.decimals(), goldenEgg.getCoopSeatInfo()[0].foodIntake);
        assertEq(1 * 10 ** eggToken.decimals(), preBalance - eggToken.balanceOf(user1));
        vm.stopPrank();

        // help feed others hen
        vm.startPrank(user2);
        preBalance = eggToken.balanceOf(user2);
        goldenEgg.helpFeedHen(user1, 0, 1 * 10 ** eggToken.decimals());
        assertEq(1 * 10 ** eggToken.decimals(), preBalance - eggToken.balanceOf(user2));
        vm.stopPrank();

        // can get hen hunger whether enter game or not.
        vm.startPrank(nonJoinGame);
        uint nonJoinFeedAmount = 1 * 10 ** eggToken.decimals();
        // nonJoinGame don't have any eggToken, so can't feed hen
        vm.expectRevert(abi.encodeWithSelector(selectorInsufficientAmount, user1, nonJoinFeedAmount));
        goldenEgg.helpFeedHen(user1, 0, nonJoinFeedAmount);

        deal(address(eggToken), nonJoinGame, 1 * 10 ** eggToken.decimals());
        goldenEgg.helpFeedHen(user1, 0, nonJoinFeedAmount);
        uint maxFoodIntake =  goldenEgg.getHenHunger(user1)[0].maxFoodIntake;
        uint foodIntake =  goldenEgg.getHenHunger(user1)[0].foodIntake;
        vm.stopPrank();


        // Althrough user feed amount is greater than maxFoodIntake, but hen can only eat maxFoodIntake
        uint biggerThanMaxFoodIntake = maxFoodIntake - foodIntake + 3 * 10 ** eggToken.decimals();
        vm.startPrank(user1);
        preBalance = eggToken.balanceOf(user1);
        goldenEgg.feedOwnHen(0, biggerThanMaxFoodIntake);   
        assertEq(goldenEgg.getHenCatalog(0).maxFoodIntake, goldenEgg.getCoopSeatInfo()[0].foodIntake);
        assertEq(maxFoodIntake - foodIntake, preBalance - eggToken.balanceOf(user1));
        assertLt(preBalance - eggToken.balanceOf(user1), biggerThanMaxFoodIntake);
        vm.stopPrank();
    }

}