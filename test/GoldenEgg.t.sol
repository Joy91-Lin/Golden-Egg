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
        vm.startPrank(user1);
        uint initProtectNumber1 = goldenEgg.startGame();
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
        assertEq(goldenEgg.initDurabilityOfProtectNumber(), goldenEgg.getAccountProtectNumbers(user1, initProtectNumber1));
        assertEq(0, goldenEgg.getAccountProtectNumbers(user1, initProtectNumber1-1));
        vm.stopPrank();

        vm.prank(user2);
        goldenEgg.startGame();
    }

    
    function test_OwnerAdmin()public{
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

    function test_checkUserisJoinGame()public{
        assertTrue(goldenEgg.isAccountJoinGame(user1));
        assertTrue(goldenEgg.isAccountJoinGame(user2));
        bytes4 selector = bytes4(keccak256("TargetDoesNotJoinGameYet(address)"));
        vm.expectRevert(abi.encodeWithSelector(selector, nonJoinGame));
        goldenEgg.isAccountJoinGame(nonJoinGame);
    }

    function test_FeedHen()public{
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

        

        vm.stopPrank();
    }

}