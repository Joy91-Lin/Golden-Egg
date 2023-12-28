pragma solidity ^0.8.17;

import {Script} from "forge-std/Script.sol";
import {Token} from "../src/Token.sol";
import {GoldenCore} from "../src/GoldenCore.sol";
import {BirthFactory} from "../src/BirthFactory.sol";
import {ChickenCoop} from "../src/ChickenCoop.sol";


contract GoldenEggScript is Script {
    GoldenCore public goldenCore;
    Token public eggToken;
    Token public litterToken;
    Token public shellToken;
    BirthFactory public birthFactory;
    ChickenCoop public chickenCoop;

    function run() public{
        uint256 userPrivateKey = vm.envUint("PRIVATE_KEY"); 
        vm.startBroadcast(userPrivateKey);

        goldenCore = new GoldenCore();
        eggToken = new Token("Egg Token", "EGG");
        litterToken = new Token("Litter Token", "LITTER");
        shellToken = new Token("Protect Shell Token", "SHELL");
        birthFactory = new BirthFactory();
        chickenCoop = new ChickenCoop(address(eggToken), address(litterToken), address(shellToken));

        vm.stopBroadcast();
    }
}