pragma solidity ^0.8.17;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./GoldenCore.sol";
contract EggToken is ERC20{
    constructor() ERC20("EggToken", "EGG") {}

    function mint(address to, uint256 amount) internal {
        _mint(to, amount);
    }

}