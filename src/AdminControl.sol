pragma solidity ^0.8.21;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract AdminControl is Ownable{
    error SenderMustBeAdmin(address caller);
    mapping(address => bool) allowers;

    constructor()Ownable(msg.sender){
    }

   modifier onlyAdmin() {
        if(allowers[msg.sender])
            _;
        else
            revert SenderMustBeAdmin(msg.sender);
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