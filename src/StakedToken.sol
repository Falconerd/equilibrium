// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import {ERC20} from "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

contract StakedToken is ERC20 {
    uint32 public constant LOCK_DURATION = 3 days;

    address public depositToken;
    mapping(address => uint32[]) public unlockTimes;
    mapping(address => uint[]) public lockedAmounts;

    constructor(address depositToken_) ERC20("Staked Equilibrium", "xEQL") {
        depositToken = depositToken_;
    }

    function deposit(uint amount_) external {
    }
}

