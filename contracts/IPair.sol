// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

interface IPair {
    function token0() external view returns (address);
    function token1() external view returns (address);
    function reserve0() external view returns (uint);
    function reserve1() external view returns (uint);
    function getAmountOut(uint, address) external view returns (uint);
}
