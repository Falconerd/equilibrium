// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

interface IOracle {
    function get_prices() external returns (uint, uint);
    function get_balances(uint total_supply) external returns (uint, uint);
}
