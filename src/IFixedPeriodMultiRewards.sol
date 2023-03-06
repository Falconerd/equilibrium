// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

interface IFixedPeriodMultiRewards {
    function rewardsDistributor(address token) external returns (address);
}
