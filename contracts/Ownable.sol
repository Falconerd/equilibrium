// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

contract Ownable {
    address public owner;

    error ZeroAddress();
    error NotOwner();

    constructor() {
        owner = msg.sender;
    }

    modifier onlyOwner {
        if (msg.sender != owner) {
            revert NotOwner();
        }
        _;
    }

    function setOwner(address newOwner) external onlyOwner {
        if (newOwner == address(0)) {
            revert ZeroAddress();
        }

        owner = newOwner;
    }
}
