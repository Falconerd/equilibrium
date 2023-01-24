// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "./IERC20.sol";

// Basic ERC20 with additional data for migration.

contract RewardToken is IERC20 {
    uint public totalSupply;
    mapping(address => uint) public balanceOf;
    mapping(address => bool) public inserted;
    address[] public holders;
    mapping(address => mapping(address => uint)) public allowance;
    string public name = "Equilibrium";
    string public symbol = "EQL";
    uint8 public decimals = 18;

    constructor() {
        totalSupply = 100_000_000;
    }

    function _transfer(address _sender, address _recipient, uint _amount) internal returns (bool) {
        balanceOf[_sender] -= _amount;
        balanceOf[_recipient] += _amount;

        // Keep track of accounts that held these tokens.
        // Useful for migration.
        if (!inserted[_recipient]) {
            inserted[_recipient] = true;
            holders.push(_recipient);
        }

        emit Transfer(msg.sender, _recipient, _amount);
        return true;
    }

    function transfer(address _recipient, uint _amount) external returns (bool) {
        return _transfer(msg.sender, _recipient, _amount);
    }

    function approve(address _spender, uint _amount) external returns (bool) {
        allowance[msg.sender][_spender] = _amount;
        emit Approval(msg.sender, _spender, _amount);
        return true;
    }

    function transferFrom(address _sender, address _recipient, uint _amount) external returns (bool) {
        allowance[_sender][msg.sender] -= _amount;
        return _transfer(_sender, _recipient, _amount);
    }
}
