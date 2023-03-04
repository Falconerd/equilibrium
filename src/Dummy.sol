// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

// This contract is only used in testing.
contract Dummy {
    function approve(address spender, address token, uint amount) public {
        IERC20(token).approve(spender, amount);
    }
}

