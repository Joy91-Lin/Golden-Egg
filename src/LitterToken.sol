pragma solidity ^0.8.17;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract LitterToken is ERC20{
    constructor() ERC20("LitterToken", "LITTER") {}

    function mint(address to, uint256 amount) internal {
        _mint(to, amount);
    }

}