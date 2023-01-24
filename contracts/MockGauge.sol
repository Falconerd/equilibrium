// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import "./IERC20.sol";
import "./IGauge.sol";

contract MockGauge is IGauge {
    address public immutable staked_token;
    mapping(address => uint) public balanceOf;

    constructor(address _staked_token) {
        staked_token = _staked_token;
    }

    function deposit(uint amount) external {
        IERC20(staked_token).transferFrom(msg.sender, address(this), amount);
        balanceOf[msg.sender] += amount;
    }

    function withdraw(uint amount) external {
        IERC20(staked_token).transfer(msg.sender, amount);
        balanceOf[msg.sender] -= amount;
    }
}

