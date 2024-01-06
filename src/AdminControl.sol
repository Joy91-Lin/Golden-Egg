pragma solidity ^0.8.21;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IGoldenError.sol";
import "./interfaces/IGoldenEvent.sol";

contract AdminControl is Ownable, IGoldenError, IGoldenEvent{
    mapping(address => bool) allowers;

    constructor()Ownable(msg.sender){
    }

   function onlyAdmin() public view {
        if(!allowers[msg.sender])
            revert SenderMustBeAdmin(msg.sender);
    }

    function onlyContractOwner() public view {
        if(msg.sender != owner()) 
            revert OwnableUnauthorizedAccount(msg.sender);
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