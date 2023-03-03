// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

interface IFarm {
    function lastTimeRewardApplicable() external returns (uint);
    function rewardPerToken() external returns (uint, uint);
    function deposit(uint amount) external;
    function withdraw(uint amount) external;
    function earned(address user) external returns (uint, uint);
    function getReward() external;
    function notifyRewardAmount(uint amount, uint booAmount) external;
}
