// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract EQL is ERC20, Ownable {
    constructor() ERC20("Equilibrium", "EQL") {
        _mint(msg.sender, 100_000_000_000);
    }
}
