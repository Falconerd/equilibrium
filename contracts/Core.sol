// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import "./Ownable.sol";
import "./Token.sol";
import "./Farm.sol";
import "./Vault.sol";

// Capabilities:
// - Deploy new farms.
// - Set current active farms.
// - Keep track of epoch's score.
// - Emit rewards to active farms.

contract Core is ICore, Ownable {
    address public immutable reward_token;

    address public active_farm_a;
    address public active_farm_b;
    address public active_farm_c;
    address public active_farm_d;

    address[] public farms;
    mapping(address => address) public farm_by_pair;

    address public vault;

    event FarmDeployed(address indexed pair, address indexed farm, uint farm_count);
    event FarmsChanged(address, address, address, address);

    constructor() {
        owner = msg.sender;
        reward_token = address(new Token());
        vault = address(new Vault());
    }

    modifier is_valid_address(address addr) {
        require(addr != address(0), "EquilibriumV1: Invalid address.");
        _;
    }

    function deploy_farm(address pair, address gauge, address oracle) external is_owner is_valid_address(pair) is_valid_address(gauge) is_valid_address(oracle) returns (address) {
        require(farm_by_pair[pair] == address(0), "EquilibriumV1: A farm for this pair has already been deployed.");

        address farm = address(new Farm(pair, gauge, oracle));

        farms.push(farm);
        farm_by_pair[pair] = farm;

        emit FarmDeployed(pair, farm, farms.length);

        return farm;
    }

    function disable_farm(address pair, string memory reason) external is_owner is_valid_address(pair) {
        Farm(farm_by_pair[pair]).mark_disabled(reason);
    }

    function set_active_farms(address a, address b, address c, address d)
        external is_owner is_valid_address(a) is_valid_address(b) is_valid_address(c) is_valid_address(d)
    {
        require(
            farm_by_pair[a] != address(0) &&
            farm_by_pair[b] != address(0) &&
            farm_by_pair[c] != address(0) &&
            farm_by_pair[d] != address(0),
            "EquilibriumV1: A farm for this pair must be deployed before it can be marked active."
        );

        active_farm_a = a;
        active_farm_b = b;
        active_farm_c = c;
        active_farm_d = d;

        emit FarmsChanged(a, b, c, d);
    }

    function change_owner(address new_owner) external is_owner is_valid_address(new_owner) {
        owner = new_owner;
    }
}
