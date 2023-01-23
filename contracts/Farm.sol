// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import "./IPair.sol";
import "./IERC20.sol";
import "./ERC20.sol";

contract Farm is ERC20 {
    //IPair public immutable pair;

    constructor() ERC20("TestFarm", "TF", 0) {
    }

    function deposit(uint amount) external {
        IERC20(msg.sender).approve(address(this), amount);
        IERC20(msg.sender).transferFrom(msg.sender, address(this), amount);
        balanceOf[msg.sender] += amount;
    }

    function withdraw(uint amount) external {
        //IERC20(msg.sender)
    }
}

