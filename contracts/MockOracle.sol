// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import "./Ownable.sol";
import "./IOrcale.sol";

contract MockOracle is IOracle, Ownable {
    constructor() {
    }

    function getPrices() external returns (uint, uint) {
        return (0, 0);
    }

    function getBalances(uint total_supply) external returns (uint, uint) {
        return (0, 0);
    }
}

