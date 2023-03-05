// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import "./IGauge.sol";
import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

contract MockGauge is IGauge {
    mapping(uint => address) tokenById;

    function setTokenById(uint id, address token) external {
        tokenById[id] = token;
    }

    function deposit(uint id, uint amount) external {
        IERC20(tokenById[id]).transferFrom(msg.sender, address(this), amount);
    }

    function withdraw(uint id, uint amount) external {
        IERC20(tokenById[id]).transfer(msg.sender, amount);
    }
}
