pragma solidity ^0.8.21;
import { console2,Test } from "forge-std/Test.sol";
import {GoldenEggScript} from "../script/GoldenEgg.s.sol";
import {GoldenEgg} from "../src/GoldenEgg.sol";


contract GoldenEggTest is Test, GoldenEggScript {
    address user1 = makeAddr("user1");
    address user2 = makeAddr("user2");
    address nonJoinGame = makeAddr("nonJoinGame");

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
        assertEq(goldenEgg.initDurabilityOfProtectNumber(), goldenEgg.getAccountProtectNumbers(user1, initProtectNumber1));
        assertEq(0, goldenEgg.getAccountProtectNumbers(user1, initProtectNumber1-1));

        vm.prank(user2);
        uint initProtectNumber2 = goldenEgg.startGame();
        assertEq(goldenEgg.initDurabilityOfProtectNumber(), goldenEgg.getAccountProtectNumbers(user2, initProtectNumber2));
        assertEq(0, goldenEgg.getAccountProtectNumbers(user2, initProtectNumber2-1));
    }

    
    function test_ownerAdmin()public{
        assertEq(deployContract, goldenEgg.owner());
        assertTrue(goldenEgg.isAdmin(address(goldenEgg)));
        assertTrue(goldenEgg.isAdmin(address(eggToken)));
        assertTrue(goldenEgg.isAdmin(address(litterToken)));
        assertTrue(goldenEgg.isAdmin(address(shellToken)));
        assertEq(deployContract, eggToken.owner());
        assertTrue(eggToken.isAdmin(address(goldenEgg)));
        assertEq(deployContract, litterToken.owner());
        assertTrue(litterToken.isAdmin(address(goldenEgg)));
        assertEq(deployContract, shellToken.owner());
        assertTrue(shellToken.isAdmin(address(goldenEgg)));
    }

    function test_entryGameInitValue()public{
        vm.startPrank(user1);
        assertEq(goldenEgg.getCoopSeatInfo(false)[0].isOpened, true);
        assertEq(goldenEgg.getCoopSeatInfo(false)[0].isExisted, true);
        uint256 initFirstHen = goldenEgg.initFirstHen();
        assertEq(goldenEgg.getCoopSeatInfo(false)[0].id, initFirstHen);
        assertEq(goldenEgg.getCoopSeatInfo(false)[0].layingTimes, 0);
        assertEq(goldenEgg.getCoopSeatInfo(false)[0].protectShellCount, 0);
        assertEq(goldenEgg.getCoopSeatInfo(false)[0].foodIntake, goldenEgg.getHenCatalog(initFirstHen).maxFoodIntake);
        assertEq(goldenEgg.getCoopSeatInfo(false)[0].layingLeftCycle, goldenEgg.getHenCatalog(initFirstHen).layingCycle);
        assertEq(goldenEgg.getCoopSeatInfo(false)[0].lastCheckBlockNumberPerSeat, block.number);
        assertEq(uint(AttackStatus.None), uint(goldenEgg.getWatchDogInfo(user1).status));
        vm.stopPrank();
    }

    function test_checkUserJoinGame()public{
        assertTrue(goldenEgg.isAccountJoinGame(user1));
        assertTrue(goldenEgg.isAccountJoinGame(user2));
        bytes4 selector = bytes4(keccak256("TargetDoesNotJoinGameYet(address)"));
        vm.expectRevert(abi.encodeWithSelector(selector, nonJoinGame));
        goldenEgg.isAccountJoinGame(nonJoinGame);
    }

    function test_feedHen()public{
        vm.startPrank(user1);
        vm.expectRevert("ChickenCoop: Hen is full.");
        goldenEgg.feedOwnHen(0, 100);

        vm.expectRevert("ChickenCoop: seat is not opened");
        goldenEgg.feedOwnHen(1, 100);

        goldenEgg.buyChickenCoopSeats{value:goldenEgg.getSellPrice().seatEthPrice}(1, false);
        vm.expectRevert("ChickenCoop: No hen in this seat");
        goldenEgg.feedOwnHen(1, 100);

        // Failed to help feed others hen
        vm.expectRevert("ChickenCoop: Hen is full.");
        goldenEgg.helpFeedHen(user2, 0, 100);

        vm.expectRevert("ChickenCoop: seat is not opened");
        goldenEgg.helpFeedHen(user2, 1, 100);

        // digest some food
        vm.roll(block.number + 1);
        uint256 preFoodIntake = goldenEgg.getCoopSeatInfo(0, false).foodIntake;
        uint consumeFood = goldenEgg.getHenCatalog(goldenEgg.getCoopSeatInfo(0, false).id).consumeFoodForOneBlock * 1;
        goldenEgg.payIncentive(user1);
        uint256 postFoodIntake = goldenEgg.getCoopSeatInfo(0, false).foodIntake;
        assertEq(preFoodIntake - postFoodIntake, consumeFood);
        vm.stopPrank();

        // feed hen
        vm.startPrank(user1);
        uint256 preBalance = eggToken.balanceOf(user1);
        goldenEgg.feedOwnHen(0, 1 * 10 ** eggToken.decimals());   
        assertEq(postFoodIntake + 1 * 10 ** eggToken.decimals(), goldenEgg.getCoopSeatInfo(0, false).foodIntake);
        assertEq(1 * 10 ** eggToken.decimals(), preBalance - eggToken.balanceOf(user1));
        vm.stopPrank();

        // help feed others hen
        vm.startPrank(user2);
        preBalance = eggToken.balanceOf(user2);
        goldenEgg.helpFeedHen(user1, 0, 2 * 10 ** eggToken.decimals());
        assertEq(2 * 10 ** eggToken.decimals(), preBalance - eggToken.balanceOf(user2));
        vm.stopPrank();

    }

}