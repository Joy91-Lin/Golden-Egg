pragma solidity ^0.8.17;
import { Test } from "forge-std/Test.sol";
import {GoldenEggScript} from "../script/GoldenEgg.s.sol";

contract GoldenEggSetUp is Test, GoldenEggScript {
    function setUp() public virtual {
    }
}