// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

interface IDepositWithdraw {
    function deposit(uint amount) external;
    function withdraw(uint amount) external;
}
