// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import {ERC20} from "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

contract VoteLockedToken is ERC20 {
    address public depositToken;

    constructor(address depositToken_) ERC20("Vote Locked Equilibrium", "vEQL") {
        depositToken = depositToken_;
    }
}

