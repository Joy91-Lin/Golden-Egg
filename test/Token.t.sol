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
        vm.prank(user1);
        goldenEgg.startGame();

        vm.prank(user2);
        goldenEgg.startGame();
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
        uint256 preBalance = eggToken.balanceOf(user1);
        eggToken.mint(user1, 100);
        vm.stopPrank();
        assertEq(eggToken.balanceOf(user1), preBalance + 100);

        // user1 can not mint
        vm.startPrank(user2);
        preBalance = eggToken.balanceOf(user2);
        vm.expectRevert(abi.encodeWithSelector(adminErrorSelector, user2));
        eggToken.mint(user2, 100);
        vm.stopPrank();
        assertEq(eggToken.balanceOf(user2), preBalance);
    }

    function test_RatioOfEth() public {
        uint256 eggRatio = eggToken.getRatioOfEth();
        uint256 litterRatio = litterToken.getRatioOfEth();
        uint256 shellRatio = shellToken.getRatioOfEth();
        assertEq(eggRatio / 2, litterRatio);
        assertEq(eggRatio / 10, shellRatio);
    }

    function test_burn() public{
        vm.startPrank(deployContract);
        uint256 preBalanceUser1 = eggToken.balanceOf(user1);
        uint256 preBalanceUser2 = eggToken.balanceOf(user2);
        eggToken.mint(user1, 200);
        eggToken.mint(user2, 200);
        vm.stopPrank();
        assertEq(eggToken.balanceOf(user1), preBalanceUser1 + 200);
        assertEq(eggToken.balanceOf(user2), preBalanceUser2 + 200);


        // user1 can not burn
        vm.startPrank(user2);
        vm.expectRevert(abi.encodeWithSelector(adminErrorSelector, user2));
        eggToken.burn(user2, 200);
        vm.stopPrank();

        // admin can burn
        vm.prank(deployContract);
        eggToken.burn(user1, 200);

        assertEq(eggToken.balanceOf(user1), preBalanceUser1);
        assertEq(eggToken.balanceOf(user2), preBalanceUser2 + 200);
    }

    function test_transfer() public{
        // admin can transfer
        vm.startPrank(deployContract);
        uint256 preBalanceUser1 = eggToken.balanceOf(user1);
        uint256 preBalanceUser2 = eggToken.balanceOf(user2);
        eggToken.mint(user1, 10_000);
        assertEq(eggToken.balanceOf(user1), preBalanceUser1 + 10_000);
        eggToken.transferFrom(user1, user2, 100);
        vm.stopPrank();

        assertEq(eggToken.balanceOf(user1), preBalanceUser1 + 10_000 - 100);
        assertEq(eggToken.balanceOf(user2), preBalanceUser2 + 100);

        // user1 can not transfer directly
        vm.startPrank(user1);
        vm.expectRevert(abi.encodeWithSelector(adminErrorSelector, user1));
        eggToken.transferFrom(user1, user2, 100);
        vm.stopPrank();

        assertEq(eggToken.balanceOf(user1), preBalanceUser1 + 10_000 - 100);
        assertEq(eggToken.balanceOf(user2), preBalanceUser2 + 100);

        // players can transfer eggToken through goldenEgg
        vm.startPrank(user1);
        preBalanceUser1 = eggToken.balanceOf(user1);
        preBalanceUser2 = eggToken.balanceOf(user2);
        goldenEgg.transferEggToken(user2, 100, false);
        vm.stopPrank();
        uint256 transferFee = goldenEgg.getSellPrice().transferTokenFeeEthPrice * eggToken.getRatioOfEth();
        assertEq(eggToken.balanceOf(user1), preBalanceUser1 - 100 - transferFee);
        assertEq(eggToken.balanceOf(user2), preBalanceUser2 + 100);

        // transfer has max limit
        bytes4 selectorReachedLimit = bytes4(keccak256("ReachedLimit(address,uint256)"));
        vm.startPrank(user1);
        uint256 biggerThanMaxTransferAmount = goldenEgg.maxTransFerTokenAmount() + 100;
        vm.expectRevert(abi.encodeWithSelector(selectorReachedLimit, user1, goldenEgg.maxTransFerTokenAmount()));
        goldenEgg.transferEggToken(user1, biggerThanMaxTransferAmount, false);
        vm.stopPrank();
    }
}