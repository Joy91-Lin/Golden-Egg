pragma solidity ^0.8.17;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract AdminControl is Ownable{
    mapping(address => bool) private allowers;

    constructor() Ownable(msg.sender) {
    }

    modifier onlyAdmin() {
        require(allowers[msg.sender], "Sender must be admin.");
        _;
    }

    function addAdmin(address account) public onlyOwner {
        allowers[account] = true;
    }

    function removeAdmin(address account) public onlyOwner {
        allowers[account] = false;
    }

    function isAdmin(address account) public view returns (bool){
        return allowers[account];
    }
}