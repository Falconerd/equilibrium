// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "./Token.sol";

// Vault where users can stake RewardToken to receive more RewardToken.
// Receipt token is ERC20 so it can be traded.

contract Vault is Token {
    Token public immutable token;

    constructor(Token token_) Token("Staked Equilibrium", "sEQL", 18, 0) {
        token = token_;
    }

    function deposit(uint amount) external {
        token.transferFrom(msg.sender, address(this), amount);
        totalSupply += amount;
        balanceOf[msg.sender] += amount;

        tryInsert(msg.sender);
    }

    function withdraw(uint amount) external {
        balanceOf[msg.sender] -= amount;
        totalSupply -= amount;
        token.transfer(msg.sender, amount);
    }
}
