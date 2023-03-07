// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import {ERC20} from "./ERC20.sol";

contract Token is ERC20 {
    constructor() ERC20("Symmetrix", "SMX") {
        _mint(_msgSender(), 1_000_000_000e18);
    }
}
