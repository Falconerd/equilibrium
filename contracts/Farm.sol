// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import "./IPair.sol";
import "./IERC20.sol";
import "./ERC20.sol";
import "./ICore.sol";

// Capabilities:
// - deposit and withdraw from gauges.
// - collect fees and bribes from gauges.
// - distribute fees and bribes to farmers.
// - keep track of tvl.

contract Farm is ERC20 {
    address public immutable core;
    address public immutable staked_token;
    address public immutable gauge;
    address public immutable oracle;
    address public immutable reward;

    bool public is_disabled = false;

    uint internal unlocked = 1;

    event Disabled(string reason);

    constructor(address _staked_token, address _gauge, address _oracle) ERC20("TestFarm", "TF") {
        core = msg.sender;
        staked_token = _staked_token;
        gauge = _gauge;
        oracle = _oracle;
        reward = ICore(msg.sender).reward_token();
    }

    modifier lock() {
        require(unlocked == 1, "EquilibriumV1: Contract is locked while performing sensitive operations.");
        unlocked = 2;
        _;
        unlocked = 1;
    }

    function mark_disabled(string memory reason) external {
        is_disabled = true;

        emit Disabled(reason);
    }

    function deposit(uint amount) external lock {
        require(is_disabled != true, "EquilibriumV1: This farm has disabled desposits.");

        //IERC20(pair)
    }

    function withdraw(uint amount) external lock {
        //IERC20(msg.sender)
    }
}

