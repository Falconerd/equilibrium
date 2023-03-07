// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

contract MockOracle {
    function consult(address, uint amount) external pure returns (uint) {
        return amount;
    }
}
