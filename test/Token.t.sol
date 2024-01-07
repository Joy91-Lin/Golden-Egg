pragma solidity ^0.8.21;

import "forge-std/Test.sol";
import {GoldenEggScript} from "../script/GoldenEgg.s.sol";
import {Token} from "../src/Token.sol";

contract TokenTest is Test, GoldenEggScript{

    address user1 = makeAddr("user1");
    address user2 = makeAddr("user2");
    bytes4 adminErrorSelector = bytes4(keccak256("SenderMustBeAdmin(address)"));

    function setUp() public{
        run();

    }

    function test_AdminControl()public{
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

    function test_mint() public{
        // admin can mint
        vm.startPrank(deployContract);
        eggToken.mint(user1, 100);
        vm.stopPrank();
        assertEq(eggToken.balanceOf(user1), 100);

        // user1 can not mint
        vm.startPrank(user2);
        vm.expectRevert(abi.encodeWithSelector(adminErrorSelector, user2));
        eggToken.mint(user2, 100);
        vm.stopPrank();
        assertEq(eggToken.balanceOf(user2), 0);
    }

    function test_burn() public{
        vm.startPrank(deployContract);
        eggToken.mint(user1, 200);
        eggToken.mint(user2, 200);
        vm.stopPrank();
        assertEq(eggToken.balanceOf(user1), 200);
        assertEq(eggToken.balanceOf(user2), 200);


        // user1 can not burn
        vm.startPrank(user2);
        vm.expectRevert(abi.encodeWithSelector(adminErrorSelector, user2));
        eggToken.burn(user2, 200);
        vm.stopPrank();

        // admin can burn
        vm.prank(deployContract);
        eggToken.burn(user1, 200);

        assertEq(eggToken.balanceOf(user1), 0);
        assertEq(eggToken.balanceOf(user2), 200);
    }

    function test_transfer() public{
        // admin can transfer
        vm.startPrank(deployContract);
        eggToken.mint(user1, 100);
        assertEq(eggToken.balanceOf(user1), 100);
        eggToken.transferFrom(user1, user2, 50);
        vm.stopPrank();

        assertEq(eggToken.balanceOf(user1), 50);
        assertEq(eggToken.balanceOf(user2), 50);

        // user1 can not transfer
        vm.startPrank(user1);
        vm.expectRevert(abi.encodeWithSelector(adminErrorSelector, user1));
        eggToken.transferFrom(user1, user2, 20);
        vm.stopPrank();

        assertEq(eggToken.balanceOf(user1), 50);
        assertEq(eggToken.balanceOf(user2), 50);
    }
}