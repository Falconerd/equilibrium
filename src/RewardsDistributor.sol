// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import {IRewardsDistributor} from "./IRewardsDistributor.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {Ownable} from "openzeppelin-contracts/contracts/access/Ownable.sol";

contract RewardsDistributor is IRewardsDistributor, Ownable {
    mapping(address => uint) public nextAmountToDistribute;
    mapping(address => bool) public isDistributee;

    modifier onlyDistributee {
        require(isDistributee[msg.sender] || msg.sender == owner(), "Not distributee");
        _;
    }
    
    function setDistributee(address user, bool active) onlyOwner external {
        isDistributee[user] = active;
    }

    function setNextAmountToDistribute(address token, uint amount) onlyDistributee external {
        require(IERC20(token).balanceOf(address(this)) >= amount, "Not enough balance");
        nextAmountToDistribute[token] = amount;
    }

    function approve(address spender, address token, uint amount) onlyOwner external {
        IERC20(token).approve(spender, amount);
    }
}
