// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

interface IGauge {
    function stake() external view returns (address);
    function withdraw(uint amount) external;
    function deposit(uint amount) external;
    function balanceOf(address account) external view returns (uint);
    function earned(address token, address account) external view returns (uint);
}
