// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import "./Token.sol";
import "./Farm.sol";
import "./Vault.sol";

contract Core {
    address public immutable eql_token;

    address public owner;

    address public active_farm_a;
    address public active_farm_b;
    address public active_farm_c;
    address public active_farm_d;

    address public vault;

    constructor() {
        owner = msg.sender;
        eql_token = address(new Token());
        active_farm_a = address(new Farm());
        active_farm_b = address(new Farm());
        active_farm_c = address(new Farm());
        active_farm_d = address(new Farm());
        vault = address(new Vault());
    }

    modifier isOwner() {
        require(msg.sender == owner, "EquilibriumV1: Only the owner can call this function.");
        _;
    }

    modifier isValidAddress(address addr) {
        require(addr != address(0), "EquilibriumV1: Invalid address.");
        _;
    }

    function changeOwner(address new_owner) external isOwner isValidAddress(new_owner) {
        owner = new_owner;
    }
}
