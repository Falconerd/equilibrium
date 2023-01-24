// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

interface IOracle {
    function getPrices() external returns (uint, uint);
    function getBalances(uint total_supply) external returns (uint, uint);
}
