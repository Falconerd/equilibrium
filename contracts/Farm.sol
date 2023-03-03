// SPDX-License-Identifier UNLICENSED
pragma solidity 0.8.17;

import "./IERC20.sol";
import "./IOracle.sol";
import "./Core.sol";
//import "hardhat/console.sol";

contract Farm is ERC20 {
    Core public immutable core;
    IERC20 public immutable stakingToken;
    IERC20 public immutable rewardsToken;
    IOracle public immutable oracle;

    uint public totalValueLocked;
    bool public isDisabled;

    struct RewardHistory {
        uint32 startTime;
        uint rewardRate;
    }

    RewardHistory[] public rewardHistory;

    uint32 public startTime;
    uint32 public epoch;
    uint32 public lastUpdateTime;
    uint public rewardPerTokenStored;

    mapping(address => uint) public userRewardPerTokenPaid;
    mapping(address => uint) public rewards;

    event Deposit(uint amount, uint totalValueLocked);
    event Withdraw(uint amount, uint totalValueLocked);
    event TotalValueLockedUpdated(uint price0, uint price1, uint balance0, uint balance1, uint totalValueLocked);

    uint internal unlocked = 1;

    constructor(address stakingToken_, address rewardsToken_, uint epoch_, address oracle_) Token("Farm", "FRM", 18, 0) {
        if (epoch_ == 0) {
            revert();
        }

        // This doesn't work in tests unless we use core to deploy the farms.
        core = Core(msg.sender);
        stakingToken = IERC20(stakingToken_);
        rewardsToken = IERC20(rewardsToken_);
        epoch = uint32(epoch_ % 2**32);
        oracle = IOracle(oracle_);
        startTime = blockTimestamp();
        // TODO: gauge, oracle, epoch
        // TODO: staingToken.approve(gauge, type(uint256).max)
    }

    modifier lock() {
        require(unlocked == 1, "Locked");
        unlocked = 2;
        _;
        unlocked = 1;
    }

    modifier updateReward(address account) {
        rewardPerTokenStored = rewardPerToken();
        lastUpdateTime = blockTimestamp();

        if (account != address(0)) {
            rewards[account] = earned(account);
            userRewardPerTokenPaid[account] = rewardPerTokenStored;
        }

        _;
    }

    function updateTotalValueLocked() internal {
        (uint price0, uint price1) = oracle.getPrices();
        if (totalSupply == 0) {
            totalValueLocked = 0;

            emit TotalValueLockedUpdated(price0, price1, 0, 0, 0);
        } else {
            (uint balance0, uint balance1) = oracle.getBalances(totalSupply);

            totalValueLocked = price0 * balance0 + price1 * balance1;

            emit TotalValueLockedUpdated(price0, price1, balance0, balance1, totalValueLocked);
        }
    }

    function notifyEpoch(uint amount, uint32 timestamp) external {
        require(msg.sender == address(core), "Not core");

        rewardHistory.push(RewardHistory({
            startTime: timestamp, rewardRate: amount / epoch
        }));

        rewardPerTokenStored = rewardPerToken();
        lastUpdateTime = blockTimestamp();
    }

    function depositFor(address account, uint amount) external onlyOwner lock updateReward(account) {
        require(isDisabled == false, "Disabled");
        require(amount > 0, "amount = 0");

        stakingToken.transferFrom(account, address(this), amount);
        // TODO: Deposit in gauge
        balanceOf[account] += amount;
        totalSupply += amount;

        updateTotalValueLocked();
        // TODO: Core update is causing transaction revert. "function call to a non-contract account"
        if (address(core) != address(0)) {
            core.update();
        }
        emit Deposit(amount, totalValueLocked);
    }

    function withdrawFor(address account, uint amount) external onlyOwner lock updateReward(account) {
        require(amount > 0, "amount = 0");
        balanceOf[account] -= amount;
        totalSupply -= amount;
        stakingToken.transfer(account, amount);
    }

    function rewardPerToken() public view returns (uint) {
        if (totalSupply == 0 || rewardHistory.length == 0) {
            return 0;
        }

        uint n = rewardPerTokenStored;
        uint t = blockTimestamp();
        // Prevent out of bounds read if block.timestamp is exactly on an epoch.
        uint firstEpochIndex = (lastUpdateTime - startTime) / epoch;
        uint lastEpochIndex = t % epoch == 0 ? (t - startTime - 1) / epoch : (t - startTime) / epoch;

        // This happens because function is called twice in updateReward.
        if (firstEpochIndex > lastEpochIndex) {
            firstEpochIndex = lastEpochIndex;
        }

        for (uint i = firstEpochIndex; i <= lastEpochIndex; ++i) {
            RewardHistory memory h = rewardHistory[i];

            if (lastUpdateTime > h.startTime) {
                n += h.rewardRate * (t - lastUpdateTime) * 1e18 / totalSupply;
            } else {
                n += h.rewardRate * (t - h.startTime) * 1e18 / totalSupply;
                t -= (t - h.startTime);
            }
        }

        return n;
    }

    function earned(address account) public view returns (uint) {
        return (balanceOf[account] * (rewardPerToken() - userRewardPerTokenPaid[account]) / 1e18) + rewards[account];
    }

    function getReward() external lock updateReward(msg.sender) {
        uint reward = rewards[msg.sender];

        if (reward > 0) {
            rewards[msg.sender] = 0;
            rewardsToken.transfer(msg.sender, reward);
        }
    }

    function blockTimestamp() public view returns (uint32) {
        return uint32(block.timestamp % 2**32);
    }
}

