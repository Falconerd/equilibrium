// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "./IOracle.sol";

contract Oracle is IOracle {
    function getPrices() external view returns (uint, uint) {
        return (3e6, 3e6);
    }

    function getBalances(uint amount) external view returns (uint, uint) {
        return (amount, amount);
    }
}

