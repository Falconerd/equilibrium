// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

// Made to work with MCV2 pools.
interface IGauge {
    function deposit(uint id, uint amount) external;
    function withdraw(uint id, uint amount) external;
}
