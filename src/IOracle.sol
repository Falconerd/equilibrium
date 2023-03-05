// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

interface IOracle {
    function getPrices() external returns (uint, uint);
    function getBalances(uint amount) external returns (uint, uint);
}

