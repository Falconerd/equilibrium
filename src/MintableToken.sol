// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import "./ERC20.sol";

contract Token is ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {
    }

    function mint(uint amount) public {
        _mint(msg.sender, amount * 1e18);
    }

    function burn(uint amount) public {
        _burn(msg.sender, amount * 1e18);
    }
}
