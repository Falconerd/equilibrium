// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

interface IOracle {
    function consult(address token, uint amountIn) external returns(uint);
}

