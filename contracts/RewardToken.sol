// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "./Token.sol";

contract RewardToken is Token {
    constructor() Token("Equilibrium", "EQL", 18, 100_000_000) {
        balanceOf[msg.sender] = 100_000_000;
        inserted[msg.sender] = true;
        holders.push(msg.sender);
    }
}
