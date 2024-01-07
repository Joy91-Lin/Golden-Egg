pragma solidity ^0.8.21;

import {Test, console2} from "forge-std/Test.sol";
import {AttackGame} from "../src/AttackGame.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../src/GoldenEgg.sol";
import "../src/Token.sol";

contract AttackGameTest is Test, AttackGame{
    address deployContract = vm.envAddress("OWNER");
    address user1 = makeAddr("user1"); // attacker
    uint256 protectNumberUser1;
    address user2 = makeAddr("user2"); // target
    uint256 protectNumberUser2;

    uint256 public requestId = 1; 

    function setUp() public {
        vm.startPrank(deployContract);
        goldenEgg = new GoldenEgg();
        AttackGame attackGame = new AttackGame();
        Token eggToken = new Token("Egg Token", "EGG", 1_000_000, address(goldenEgg), address(attackGame));
        Token litterToken = new Token("Litter Token", "LITTER", 500_000, address(goldenEgg), address(attackGame));
        Token shellToken = new Token("Protect Shell Token", "SHELL",100_000, address(goldenEgg), address(attackGame));
        goldenEgg.setUpAddress(
            address(eggToken),
            address(litterToken),
            address(shellToken),
            address(attackGame));
        attackGame.setUpAddress(
            address(eggToken),
            address(litterToken),
            address(shellToken),
            address(goldenEgg));
        eggTokenAddress = address(eggToken);
        litterTokenAddress = address(litterToken);
        shellTokenAddress = address(shellToken);

        uint layingCycle = 200;
        uint consumeFoodForOneBlock = 5 * 10 ** eggToken.decimals();
        uint maxFoodIntake = 500 * 10 ** eggToken.decimals();
        uint unitEggToken = 2000 * 10 ** eggToken.decimals();
        uint unitLitterToken = 300 * 10 ** litterToken.decimals();
        uint protectShellPeriod = 10;
        uint unitShellToken = 100 * 10 ** shellToken.decimals();
        uint purchaseLimit = 3;
        uint ethPrice = 0.0001 ether;
        uint eggPrice = ethPrice * eggToken.getRatioOfEth();
        bool isOnSale = true;
        goldenEgg.createHen(layingCycle, consumeFoodForOneBlock, maxFoodIntake, unitEggToken, unitLitterToken, protectShellPeriod, unitShellToken, purchaseLimit, ethPrice, eggPrice, isOnSale);
        uint compensationPercentageMantissa = 10;
        uint lostPercentageMantissa = 10;
        goldenEgg.createDog(compensationPercentageMantissa, lostPercentageMantissa, ethPrice, eggPrice, isOnSale);
        // let player have litter token
        IToken(litterTokenAddress).mint(user1, 500 * 10 ** IToken(litterTokenAddress).decimals());
        IToken(litterTokenAddress).mint(user2, 500 * 10 ** IToken(litterTokenAddress).decimals());
        vm.stopPrank();

        vm.prank(user1);
        protectNumberUser1 = goldenEgg.startGame();

        vm.prank(user2);
        protectNumberUser2 = goldenEgg.startGame();

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

    function test_attackSuccess()public{
        vm.roll(block.number + 1000);
        attacks[requestId] = Attack({
            chainLinkFees: 3,
            attacker: payable(user1),
            target: user2,
            attackRandom: 0,
            reward: 0,
            litter: 0,
            attackResult: false,
            status: AttackStatus.Pending
        });
        vm.startPrank(deployContract);
        goldenEgg.setForAttackGameStart(requestId, user1, user2);

        assertEq(uint(goldenEgg.getWatchDogInfo(user2).status), uint(AttackStatus.Pending));
        uint256 beforeEggUser1 = IToken(eggTokenAddress).balanceOf(user1);
        uint256 beforeLitterUser1 = IToken(litterTokenAddress).balanceOf(user1);
        uint256 beforeShellUser1 = IToken(shellTokenAddress).balanceOf(user1);

        uint256 beforeEggUser2 = IToken(eggTokenAddress).balanceOf(user2);
        uint256 beforeLitterUser2 = IToken(litterTokenAddress).balanceOf(user2);
        uint256 beforeShellUser2 = IToken(shellTokenAddress).balanceOf(user2);
        uint256[] memory randomWords = new uint256[](1);
        randomWords[0] = protectNumberUser2 + 100 ;
        fulfillRandomWords(requestId, randomWords);
        uint256 afterEggUser1 = IToken(eggTokenAddress).balanceOf(user1);
        uint256 afterLitterUser1 = IToken(litterTokenAddress).balanceOf(user1);
        uint256 afterShellUser1 = IToken(shellTokenAddress).balanceOf(user1);

        uint256 afterEggUser2 = IToken(eggTokenAddress).balanceOf(user2);
        uint256 afterLitterUser2 = IToken(litterTokenAddress).balanceOf(user2);
        uint256 afterShellUser2 = IToken(shellTokenAddress).balanceOf(user2);

        assertEq(uint(goldenEgg.getWatchDogInfo(user2).status), uint(AttackStatus.Completed));
        assertEq(attacks[requestId].attackResult, true);
        assertLt(beforeEggUser1, afterEggUser1);
        assertGt(beforeLitterUser1, afterLitterUser1);
        assertEq(beforeShellUser1, afterShellUser1);
        assertGt(beforeEggUser2, afterEggUser2);
        assertLt(beforeLitterUser2, afterLitterUser2);
        assertLt(beforeShellUser2, afterShellUser2);


        vm.stopPrank();
    }

    function test_attackFail()public{
        vm.roll(block.number + 1000);
        attacks[requestId] = Attack({
            chainLinkFees: 3,
            attacker: payable(user1),
            target: user2,
            attackRandom: 0,
            reward: 0,
            litter: 0,
            attackResult: false,
            status: AttackStatus.Pending
        });
        vm.startPrank(deployContract);
        goldenEgg.setForAttackGameStart(requestId, user1, user2);
        assertEq(uint(goldenEgg.getWatchDogInfo(user2).status), uint(AttackStatus.Pending));
        uint256 durabilityBefore = goldenEgg.getAccountProtectNumberDurability(user2, protectNumberUser2);
        uint256 beforeEggUser1 = IToken(eggTokenAddress).balanceOf(user1);
        uint256 beforeLitterUser1 = IToken(litterTokenAddress).balanceOf(user1);
        uint256 beforeShellUser1 = IToken(shellTokenAddress).balanceOf(user1);

        uint256 beforeEggUser2 = IToken(eggTokenAddress).balanceOf(user2);
        uint256 beforeLitterUser2 = IToken(litterTokenAddress).balanceOf(user2);
        uint256 beforeShellUser2 = IToken(shellTokenAddress).balanceOf(user2);

        uint256[] memory randomWords = new uint256[](1);
        randomWords[0] = protectNumberUser2 + 100 - 1;
        fulfillRandomWords(requestId, randomWords);
        uint256 durabilityAfter = goldenEgg.getAccountProtectNumberDurability(user2, protectNumberUser2);
        uint256 afterEggUser1 = IToken(eggTokenAddress).balanceOf(user1);
        uint256 afterLitterUser1 = IToken(litterTokenAddress).balanceOf(user1);
        uint256 afterShellUser1 = IToken(shellTokenAddress).balanceOf(user1);

        uint256 afterEggUser2 = IToken(eggTokenAddress).balanceOf(user2);
        uint256 afterLitterUser2 = IToken(litterTokenAddress).balanceOf(user2);
        uint256 afterShellUser2 = IToken(shellTokenAddress).balanceOf(user2);

        assertEq(uint(goldenEgg.getWatchDogInfo(user2).status), uint(AttackStatus.Completed));
        assertFalse(attacks[requestId].attackResult);
        assertGt(durabilityBefore, durabilityAfter);
        assertEq(beforeEggUser1, afterEggUser1);
        assertEq(beforeLitterUser1, afterLitterUser1);
        assertEq(beforeShellUser1, afterShellUser1);
        assertEq(beforeEggUser2, afterEggUser2);
        assertEq(beforeLitterUser2, afterLitterUser2);
        assertEq(beforeShellUser2, afterShellUser2);


        vm.stopPrank();
    }

}