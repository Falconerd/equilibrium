// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

interface IRewardsDistributor {
    function setDistributee(address user, bool active) external;
    function nextAmountToDistribute(address token) external returns (uint);
    function setNextAmountToDistribute(address token, uint amount) external;
    function approve(address spender, address token, uint amount) external;
}
