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

    address[] public farms;
    mapping(address => address) public farm_by_pair;

    address public vault;

    event FarmDeployed(address indexed pair, address farm, uint farm_count);

    constructor() {
        owner = msg.sender;
        eql_token = address(new Token());
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

    function deploy(address pair_address) external isOwner isValidAddress(pair_address) {
        require(farm_by_pair[pair_address] == address(0), "EquilibriumV1: A farm for this pair has already been deployed.");
        address farm_address = address(new Farm());

        farms.push(farm_address);
        farm_by_pair[pair_address] = farm_address;

        emit FarmDeployed(pair_address, farm_address, farms.length);
    }

    function setActiveFarms(address a, address b, address c, address d)
        external isOwner isValidAddress(a) isValidAddress(b) isValidAddress(c) isValidAddress(d)
    {
        require(farm_by_pair[a] != address(0), "EquilibriumV1: A farm for this pair must be deployed before it can be marked active.");
        require(farm_by_pair[b] != address(0), "EquilibriumV1: A farm for this pair must be deployed before it can be marked active.");
        require(farm_by_pair[c] != address(0), "EquilibriumV1: A farm for this pair must be deployed before it can be marked active.");
        require(farm_by_pair[d] != address(0), "EquilibriumV1: A farm for this pair must be deployed before it can be marked active.");

        active_farm_a = a;
        active_farm_b = b;
        active_farm_c = c;
        active_farm_d = d;
    }

    function changeOwner(address new_owner) external isOwner isValidAddress(new_owner) {
        owner = new_owner;
    }
}
