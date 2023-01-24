// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

contract Ownable {
    address public owner;

    modifier is_owner() {
        require(msg.sender == owner, "EquilibriumV1: Only the owner can call this function.");
        _;
    }
}
