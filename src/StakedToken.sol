// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import {FixedPeriodMultiRewards} from "./FixedPeriodMultiRewards.sol";
import {IDistributor} from "./Distributor.sol";

contract StakedToken is FixedPeriodMultiRewards {
    constructor(address stake_) FixedPeriodMultiRewards(stake_, address(0), 0, "Staked Symmetrix", "vSMX") {}

    function setNextAmountToDistribute(address token, uint amount) external onlyOwner {
        IDistributor(distributor[token]).setNextAmountToDistribute(token, amount);
    }
}

