// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "./IMCV2.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// Provide QOL functions for getting SpookySwap data.
contract SpookyQuery {
    function findSpookyPoolByAddress(IMCV2 masterChef, IERC20 poolToken) external returns (bool, uint) {
        uint poolCount = masterChef.poolLength();
        for (uint i = 0; i < poolCount; ++i) {
            address lpToken = masterChef.lpToken(i);
            if (lpToken == address(poolToken)) {
                return (true, i);
            }
        }

        return (false, 0);
    }
}
