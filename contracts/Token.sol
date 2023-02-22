// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "./IERC20.sol";
import "hardhat/console.sol";

// Basic ERC20 with additional data for migration.

contract Token is IERC20 {
    uint public totalSupply;
    mapping(address => uint) public balanceOf;
    mapping(address => bool) public inserted;
    address[] public holders;
    mapping(address => mapping(address => uint)) public allowance;
    string public name;
    string public symbol;
    uint8 public decimals;

    constructor(string memory name_, string memory symbol_, uint8 decimals_, uint startingSupply) {
        name = name_;
        symbol = symbol_;
        decimals = decimals_;
        totalSupply = startingSupply;

        balanceOf[msg.sender] = startingSupply;
        tryInsert(msg.sender);

        emit Transfer(address(0), msg.sender, startingSupply);
    }

    function tryInsert(address addr) internal {
        if (!inserted[addr]) {
            inserted[addr] = true;
            holders.push(addr);
        }
    }

    function internalTransfer(address sender, address recipient, uint amount) internal returns (bool) {
        balanceOf[sender] -= amount;
        balanceOf[recipient] += amount;

        // Keep track of accounts that held these tokens.
        // Useful for migration.
        tryInsert(recipient);

        emit Transfer(msg.sender, recipient, amount);
        return true;
    }

    function transfer(address recipient, uint amount) external returns (bool) {
        require(balanceOf[msg.sender] >= amount, "Not enough balance");
        return internalTransfer(msg.sender, recipient, amount);
    }

    function approve(address spender, uint amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(address sender, address recipient, uint amount) external returns (bool) {
        require(allowance[sender][msg.sender] >= amount, "Not enough allowance");
        allowance[sender][msg.sender] -= amount;
        return internalTransfer(sender, recipient, amount);
    }
}
