// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import "./ERC20.sol";

contract Farm is ERC20 {
    constructor() ERC20("TestFarm", "TF", 0) {
    }
}

