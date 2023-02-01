// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "./IERC20.sol";
import "./Token.sol";
import "./Ownable.sol";

contract StakingRewards is Token, Ownable {
    IERC20 public immutable stakingToken;
    IERC20 public immutable rewardsToken;

    uint public duration;
    uint public finishAt;
    uint public updatedAt;
    uint public rewardRate;
    uint public rewardPerTokenStored;
    mapping(address => uint) public userRewardPerTokenPaid;
    mapping(address => uint) public rewards;

    constructor(address stakingToken_, address rewardsToken_) Token("StakingTest", "STT", 18, 0) {
        stakingToken = IERC20(stakingToken_);
        rewardsToken = IERC20(rewardsToken_);
    }

    modifier updateReward(address account) {
        rewardPerTokenStored = rewardPerToken();
        updatedAt = lastTimeRewardApplicable();
        if (account != address(0)) {
            rewards[account] = earned(account);
            userRewardPerTokenPaid[account] = rewardPerTokenStored;
        }
        _;
    }

    function setRewardsDuration(uint duration_) external onlyOwner {
        require(finishAt < block.timestamp, "Reward duration not finished");
        duration = duration_;
    }

    function notifyRewardAmount(uint amount) external onlyOwner updateReward(address(0)) {
        if (block.timestamp > finishAt) {
            rewardRate = amount / duration;
        } else {
            uint remainingRewards = rewardRate * (finishAt - block.timestamp);
            rewardRate = (remainingRewards + amount) / duration;
        }

        require(rewardRate > 0, "reward rate = 0");
        require(rewardRate * duration <= rewardsToken.balanceOf(address(this)), "reward amount > balance");

        finishAt = block.timestamp + duration;
        updatedAt = block.timestamp;
    }

    function stake(uint amount) external updateReward(msg.sender) {
        require(amount > 0, "amount = 0");
        stakingToken.transferFrom(msg.sender, address(this), amount);
        balanceOf[msg.sender] += amount;
        totalSupply += amount;
    }

    function withdraw(uint amount) external updateReward(msg.sender) {
        require(amount > 0, "amount = 0");
        balanceOf[msg.sender] -= amount;
        totalSupply -= amount;
        stakingToken.transfer(msg.sender, amount);
    }

    function lastTimeRewardApplicable() public view returns (uint) {
        return min(block.timestamp, finishAt);
    }

    function rewardPerToken() public view returns (uint) {
        if (totalSupply == 0) {
            return rewardPerTokenStored;
        }
        return rewardPerTokenStored + (rewardRate * (lastTimeRewardApplicable() - updatedAt) * 1e18) / totalSupply;
    }

    function earned(address account) public view returns (uint) {
        return (balanceOf[account] * (rewardPerToken() - userRewardPerTokenPaid[account])) / 1e18 + rewards[account];
    }

    function getReward() external updateReward(msg.sender) {
        uint reward = rewards[msg.sender];
        if (reward > 0) {
            rewards[msg.sender] = 0;
            rewardsToken.transfer(msg.sender, reward);
        }
    }

    function min(uint x, uint y) private pure returns (uint) {
        return x <= y ? x : y;
    }
}
