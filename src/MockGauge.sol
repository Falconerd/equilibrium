// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import "./IGauge.sol";
import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "openzeppelin-contracts/contracts/access/Ownable.sol";

// A test gauge for simulating a MasterChef contract like 
// the MCV2 and MCV3 that SpookySwap are using.
// In this case we just supply the same rewardRate for every
// token type.
contract MockGauge is IGauge, Ownable {
    mapping(uint => address) tokenById;
    // User => Token ID => Balance
    mapping(address => mapping(uint => uint)) balances;
    mapping(uint => uint) totalSupplies;
    uint rewardRate = 4e18;
    IERC20 rewardToken;

    uint duration = 60 * 60 * 24 * 365;
    uint finishAt;

    mapping(uint => uint) updatedAt;
    mapping(uint => uint) rewardPerTokenStored;
    mapping(address => mapping(uint => uint)) userRewardPerTokenPaid;
    mapping(address => mapping(uint => uint)) rewards;

    constructor() {
        finishAt = block.timestamp + duration;
    }

    modifier updateReward(uint id, address user) {
        // If no rewardToken set up, no need to do anything.
        if (address(rewardToken) != address(0)) {
            rewardPerTokenStored[id] = rewardPerToken(id);
            updatedAt[id] = block.timestamp;

            if (user != address(0)) {
                rewards[user][id] = earned(id, user);
                userRewardPerTokenPaid[user][id] = rewardPerTokenStored[id];
            }
        }
        _;
    }

    function setRewardToken(address rewardToken_) external onlyOwner {
        rewardToken = IERC20(rewardToken_);
    }

    function setTokenById(uint id, address token) external onlyOwner {
        tokenById[id] = token;
    }

    function rewardPerToken(uint id) public view returns (uint) {
        if (totalSupplies[id] == 0) {
            return rewardPerTokenStored[id];
        }

        return rewardPerTokenStored[id] + (rewardRate * (block.timestamp - updatedAt[id]) * 1e18) / totalSupplies[id];
    }

    function deposit(uint id, uint amount) external updateReward(id, msg.sender) {
        require(tokenById[id] != address(0), "Unrecognised token");
        IERC20(tokenById[id]).transferFrom(msg.sender, address(this), amount);

        // Simulate BOO auto-transfer.
        getReward(id);

        balances[msg.sender][id] += amount;
        totalSupplies[id] += amount;
    }

    function withdraw(uint id, uint amount) external updateReward(id, msg.sender) {
        require(tokenById[id] != address(0), "Unrecognised token");
        require(balances[msg.sender][id] >= amount);
        balances[msg.sender][id] -= amount;
        totalSupplies[id] -= amount;

        // Simulate BOO auto-transfer.
        getReward(id);

        IERC20(tokenById[id]).transfer(msg.sender, amount);
    }

    function earned(uint id, address user) public view returns (uint) {
        return ((balances[user][id] * (rewardPerToken(id) - userRewardPerTokenPaid[user][id])) / 1e18) + rewards[user][id];
    }

    function getReward(uint id) public updateReward(id, msg.sender) {
        uint reward = rewards[msg.sender][id];
        if (reward > 0) {
            rewards[msg.sender][id] = 0;
            rewardToken.transfer(msg.sender, reward);
        }
    }
}
