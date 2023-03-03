// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

interface IFarm {
    function lastTimeRewardApplicable() external returns (uint);
    function rewardPerToken(address rewardsToken) external returns (uint);
    function deposit(uint amount) external;
    function withdraw(uint amount) external;
    function earned(address user, address rewardsToken) external returns (uint);
    function getReward() external;
    function startNextEpoch() external;
}
