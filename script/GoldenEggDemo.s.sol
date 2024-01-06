pragma solidity ^0.8.21;

import {Script} from "forge-std/Script.sol";
import {Token} from "../src/Token.sol";
import {GoldenTop} from "../src/GoldenTop.sol";
import {BirthFactory} from "../src/BirthFactory.sol";
import {ChickenCoop} from "../src/ChickenCoop.sol";
import {WatchDog} from "../src/WatchDog.sol";
import {GoldenEgg} from "../src/GoldenEgg.sol";
import {console2} from "forge-std/Console2.sol";
import {AttackGame} from "../src/AttackGame.sol";


contract GoldenEggScript is Script {
    address deployContract = vm.envAddress("OWNER");
    Token public eggToken;
    Token public litterToken;
    Token public shellToken;
    GoldenEgg public goldenEgg;
    AttackGame public attackGame;

    function run() public{
        uint256 userPrivateKey = vm.envUint("PRIVATE_KEY"); 
        vm.startBroadcast(userPrivateKey);


        goldenEgg = new GoldenEgg();
        attackGame = new AttackGame();
        eggToken = new Token("Egg Token", "EGG", 10_000, address(goldenEgg), address(attackGame));
        litterToken = new Token("Litter Token", "LITTER", 5_000, address(goldenEgg), address(attackGame));
        shellToken = new Token("Protect Shell Token", "SHELL",1_000, address(goldenEgg), address(attackGame));
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
        vm.stopBroadcast();
    }
}