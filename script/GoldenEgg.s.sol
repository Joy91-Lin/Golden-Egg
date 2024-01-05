pragma solidity ^0.8.21;

import {Script} from "forge-std/Script.sol";
import {Token} from "../src/Token.sol";
import {GoldenTop} from "../src/GoldenTop.sol";
import {BirthFactory} from "../src/BirthFactory.sol";
import {ChickenCoop} from "../src/ChickenCoop.sol";
import {WatchDog} from "../src/WatchDog.sol";
import {GoldenEgg} from "../src/GoldenEgg.sol";
import {console2} from "forge-std/Console2.sol";


contract GoldenEggScript is Script {
    address deployContract = 0x4ff1B1f7b28345eFC5e8f628A19e96c34696dbF0;
    Token public eggToken;
    Token public litterToken;
    Token public shellToken;
    GoldenEgg public goldenEgg;

    function run() public{
        uint256 userPrivateKey = vm.envUint("PRIVATE_KEY"); 
        vm.startBroadcast(userPrivateKey);

        goldenEgg = new GoldenEgg();
        eggToken = new Token("Egg Token", "EGG", 10_000, address(goldenEgg));
        litterToken = new Token("Litter Token", "LITTER", 5_000, address(goldenEgg));
        shellToken = new Token("Protect Shell Token", "SHELL",1_000, address(goldenEgg));
        goldenEgg.setUpAddress(
            address(eggToken),
            address(litterToken),
            address(shellToken));
        uint layingCycle = 200;
        uint consumeFoodForOneBlock = 5 * 10 ** eggToken.decimals();
        uint maxFoodIntake = 500 * 10 ** eggToken.decimals();
        uint unitEggToken = 2000 * 10 ** eggToken.decimals();
        uint unitLitterToken = 300 * 10 ** litterToken.decimals();
        uint protectShellPeriod = 10;
        uint purchaseLimit = 3;
        uint ethPrice = 0.0001 ether;
        uint eggPrice = ethPrice * eggToken.getRatioOfEth();
        bool isOnSale = true;
        goldenEgg.createHen(layingCycle, consumeFoodForOneBlock, maxFoodIntake, unitEggToken, unitLitterToken, protectShellPeriod, purchaseLimit, ethPrice, eggPrice, isOnSale);
        uint rewardPercentageMantissa = 10;
        uint dumpPercentageMantissa = 10;
        goldenEgg.createDog(rewardPercentageMantissa, dumpPercentageMantissa, ethPrice, eggPrice, isOnSale);
        vm.stopBroadcast();
    }
}