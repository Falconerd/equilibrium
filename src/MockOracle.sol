// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import "./IOracle.sol";

contract MockOracle is IOracle {
    uint b0;
    uint b1;
    uint p0;
    uint p1;

    function getBalances(uint amount) external returns (uint, uint) {
        return (0, 0);
    }

    function getPrices() external returns (uint, uint) {
        return (0, 0);
    }

    function setBalances(uint b0_, uint b1_) public {
        b0 = b0_;
        b1 = b1_;
    }

    function setPrices(uint p0_, uint p1_) public {
        p0 = p0_;
        p1 = p1_;
    }
}
