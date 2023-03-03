// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

interface ICore {
    // Farm management.
    function deploy(address depositToken) external returns (address);
    function setActiveFarms(address farms) external;
    function update() external;
}
