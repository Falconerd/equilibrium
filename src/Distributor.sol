// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import {Ownable} from "./Ownable.sol";
import {IERC20} from "./ERC20.sol";

interface IDistributor {
    function nextAmountToDistribute(address token) external returns (uint);
    function setNextAmountToDistribute(address token, uint amount) external;
}

contract Distributor is IDistributor, Ownable {
    address public receiver;
    mapping(address => uint) public nextAmountToDistribute;

    constructor(address receiver_) {
        receiver = receiver_;
    }

    function setNextAmountToDistribute(address token, uint amount) external {
        require(msg.sender == receiver, "Distributor: Only the receiver can set the next amount");
        require(IERC20(token).balanceOf(address(this)) >= amount, "Distributor: Not enough balance");
        nextAmountToDistribute[token] = amount;
    }

    function approve(address spender, address token, uint amount) onlyOwner external {
        IERC20(token).approve(spender, amount);
    }
}

