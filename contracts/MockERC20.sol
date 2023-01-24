// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import "./ERC20.sol";

contract MockERC20 is ERC20 {
    event TokenCreated(string n);

    constructor(string memory s) ERC20(s, s) {
        _mint(msg.sender, 1e22);

        emit TokenCreated(s);
    }
}

