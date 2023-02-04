// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

interface IOracle {
    function getPrices() external view returns (uint, uint);
    function getBalances(uint amount) external view returns (uint, uint);
}
