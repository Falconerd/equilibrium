// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import "./IOracle.sol";

// Mock Oracle, tokens always worth 1 USDC.
contract MockOracle is IOracle {
    function consult(address, uint amountIn) external pure returns (uint) {
        return amountIn * 1e6;
    }
}
