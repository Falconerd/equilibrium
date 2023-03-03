// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

interface IRewardsDistributor {
    function pushRewardToken(address token) external;
}
