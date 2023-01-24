// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import "./IPair.sol";
import "./IERC20.sol";
import "./ERC20.sol";

contract Farm is ERC20 {
    address public immutable core;
    address public immutable pair;
    address public immutable gauge;
    address public immutable oracle;

    constructor(address _pair, address _gauge, address _oracle) ERC20("TestFarm", "TF", 0) {
        core = msg.sender;
        pair = _pair;
        gauge = _gauge;
        oracle = _oracle;
    }

    uint internal unlocked = 1;
    modifier lock() {
        require(unlocked == 1, "EquilibriumV1: Contract is locked while performing sensitive operations.");
        unlocked = 2;
        _;
        unlocked = 1;
    }

    function deposit(uint amount) external {
        IERC20(msg.sender).approve(address(this), amount);
        IERC20(msg.sender).transferFrom(msg.sender, gauge, amount);
        balanceOf[msg.sender] += amount;
    }

    function withdraw(uint amount) external {
        //IERC20(msg.sender)
    }
}

