// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import "./ERC20.sol";

contract Token is ERC20 {
    constructor() ERC20("Equilibrium", "EQL", 1_000_000_000) {
    }
}
