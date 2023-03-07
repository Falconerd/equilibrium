// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import {ERC20} from "./ERC20.sol";

contract MockPair is ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {
    }

    function mint(uint amount) public {
        _mint(_msgSender(), amount * 1e18);
    }
}

