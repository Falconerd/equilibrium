// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import {IRewardsDistributor} from "./IRewardsDistributor.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {Ownable} from "openzeppelin-contracts/contracts/access/Ownable.sol";
import {Pausable} from "openzeppelin-contracts/contracts/security/Pausable.sol";

contract RewardsDistributor is IRewardsDistributor, Ownable, Pausable {
    mapping(address => uint) public nextAmountToDistribute;

    function setNextAmountToDistribute(address token, uint amount) whenNotPaused onlyOwner external {
        require(IERC20(token).balanceOf(address(this)) >= amount, "Not enough balance");
        nextAmountToDistribute[token] = amount;
    }

    function approve(address spender, address token, uint amount) external {
        IERC20(token).approve(spender, amount);
    }
}
