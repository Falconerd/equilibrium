// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

interface IFarm {
    function totalValueLocked() external returns (uint);
    function addReward(address token, address distributor) external;
}
