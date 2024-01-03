pragma solidity ^0.8.21;
import { console2,Test } from "forge-std/Test.sol";
import {GoldenEggScript} from "../script/GoldenEgg.s.sol";

contract GoldenEggSetUp is Test, GoldenEggScript {

    address user1 = makeAddr("user1");
    address user2 = makeAddr("user2");
    function setUp() public {
        run();
        vm.roll(1000);
        deal(user1, 100 ether);
        deal(user1, 100 ether);

    }

    function test()public{
        vm.prank(user1);
        uint initProtectNumber1 = goldenEgg.startGame();

        vm.prank(user2);
        uint initProtectNumber2 = goldenEgg.startGame();
        console2.log("user1 protectNumber", initProtectNumber1);
        console2.log("user2 protectNumber", initProtectNumber2);

    }

}