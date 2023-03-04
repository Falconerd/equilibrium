// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import {ERC20} from "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {Ownable} from "openzeppelin-contracts/contracts/access/Ownable.sol";
import {Pausable} from "openzeppelin-contracts/contracts/security/Pausable.sol";

// Modified MultiRewards contract to use a fixed-time period.
// - Reward Tokens require a Distributor contract that has allows this
//   contract to spend the Reward Token.
// - Each new Period, all Reward Tokens are sent from each distributor
//   to this contract, and the rewardRate is set to the totalSupply of
//   the distributor before sending.
contract FixedPeriodMultiRewards is ERC20, Ownable, Pausable {
    uint   public immutable period;
    IERC20 public immutable depositToken;

    uint public contractDeployTime;
    uint public lastRewardsUpdateTime;
    uint public nextPeriodTime;

    IERC20[] public rewardTokens;

    // Keep track of rewards for each token per period.
    struct RewardHistory {
        uint timestamp;
        uint rewardRate;
    }

    // Reward Token => Value.
    // Use the getRewardHistory function.
    mapping(address => RewardHistory[]) private rewardHistory;
    mapping(address => uint) public rewardPerTokenStored;
    mapping(address => address) public rewardsDistributorByRewardsToken;

    // User => Reward Token => Amount.
    mapping(address => mapping(address => uint)) public userRewardPerTokenPaid;
    mapping(address => mapping(address => uint)) public rewards;

    address private _periodStarter;
    uint    private _unlocked = 1;

    /* ================ MODIFIERS ================ */

    modifier lock() {
        require(_unlocked == 1, "Locked");
        _unlocked = 2;
        _;
        _unlocked = 1;
    }

    modifier updateReward(address user) {
        for (uint i = 0; i < rewardTokens.length; ++i) {
            address token = address(rewardTokens[i]);
            rewardPerTokenStored[token] = rewardPerToken(token);
            if (user != address(0)) {
                rewards[user][token] = earned(user, token);
                userRewardPerTokenPaid[user][token] = rewardPerTokenStored[token];
            }
        }

        lastRewardsUpdateTime = lastTimeRewardApplicable();
        _;
    }

    /* =============== INIT ================ */

    constructor(
        IERC20 depositToken_,
        uint period_,
        string memory tokenName_,
        string memory tokenSymbol_
    ) ERC20(tokenName_, tokenSymbol_) {
        depositToken = depositToken_;
        period = period_;
        contractDeployTime = block.timestamp;
    }

    function addReward(address rewardsToken_, address rewardsDistributor_) public onlyOwner {
        require(rewardsDistributorByRewardsToken[rewardsToken_] == address(0));
        rewardTokens.push(IERC20(rewardsToken_));
        rewardsDistributorByRewardsToken[rewardsToken_] = rewardsDistributor_;
    }

    /* =============== VIEWS ================ */

    function getRewardHistory(address token, uint index) external view returns (RewardHistory memory) {
        RewardHistory[] storage history = rewardHistory[token];
        require(index < history.length, "Out of bounds index");
        return history[index];
    }

    function rewardTokensLength() external view returns (uint) {
        return rewardTokens.length;
    }

    function lastTimeRewardApplicable() public view returns (uint) {
        if (nextPeriodTime == 0) {
            return 0;
        } else {
            return _min(nextPeriodTime - period, block.timestamp);
        }
    }

    function rewardPerToken(address rewardsToken) public view returns (uint) {
        if (totalSupply() == 0 || rewardHistory[rewardsToken].length == 0) {
            return (0);
        }

        uint n = rewardPerTokenStored[rewardsToken];
        uint time = block.timestamp;
        // Prevent out of bounds read if block.timestamp is exactly on an period.
        uint firstPeriodIndex = (lastRewardsUpdateTime - contractDeployTime) / period;
        uint lastPeriodIndex;
        if (rewardHistory[rewardsToken].length > 1) {
            lastPeriodIndex = time % period == 0 ? (time - contractDeployTime - 1) / period : (time - contractDeployTime) / period;
        }

        if (firstPeriodIndex > lastPeriodIndex) {
            firstPeriodIndex = lastPeriodIndex;
        }

        for (uint i = firstPeriodIndex; i <= lastPeriodIndex; ++i) {
            RewardHistory memory h = rewardHistory[rewardsToken][i];

            if (lastRewardsUpdateTime > h.timestamp) {
                n += h.rewardRate * (time - lastRewardsUpdateTime) * 1e18 / totalSupply();
            } else {
                n += h.rewardRate * (time - contractDeployTime) * 1e18 / totalSupply();
                time -= (time - h.timestamp);
            }
        }

        return n;
    }

    function earned(address user, address rewardsToken) public view returns (uint) {
        return (balanceOf(user) * (rewardPerToken(user) - userRewardPerTokenPaid[user][rewardsToken]) / 1e18) + rewards[user][rewardsToken];
    }

    /* ================ MUTATIVE FUNCTIONS ================ */

    function deposit(uint amount) external whenNotPaused lock updateReward(msg.sender) {
        require(amount > 0, "Nothing to deposit");
        depositToken.transferFrom(msg.sender, address(this), amount);
        _mint(msg.sender, amount);
    }

    function withdraw(uint amount) external lock updateReward(msg.sender) {
        require(amount > 0, "Nothing to withdraw");
        _burn(msg.sender, amount);
        depositToken.transfer(msg.sender, amount);
    }

    function getReward() external lock updateReward(msg.sender) {
        for (uint i = 0; i < rewardTokens.length; ++i) {
            address rewardsToken = address(rewardTokens[i]);
            uint reward = rewards[msg.sender][rewardsToken];
            if (reward > 0) {
                rewards[msg.sender][rewardsToken] = 0;
                IERC20(rewardsToken).transfer(msg.sender, reward);
            }
        }
    }

    function touch() external updateReward(msg.sender) {}

    /* ================ RESTRICTED FUNCTIONS ================ */

    function setRewardsDistributor(address rewardsToken, address rewardsDistributor) external onlyOwner {
        rewardsDistributorByRewardsToken[rewardsToken] = rewardsDistributor;
    }

    function setPeriodStarter(address account) external onlyOwner {
        _periodStarter = account;
    }

    function startNextPeriod() external updateReward(address(0)) {
        require(msg.sender == _periodStarter);

        uint time = block.timestamp;

        require(time >= nextPeriodTime, "Period has not yet finished");

        for (uint i = 0; i < rewardTokens.length; ++i) {
            address token = address(rewardTokens[i]);
            address distributor = rewardsDistributorByRewardsToken[token];

            rewardHistory[token].push(RewardHistory({
                timestamp: time,
                rewardRate: IERC20(token).balanceOf(distributor)
            }));
            rewardPerTokenStored[token] = rewardPerToken(token);

            // Always transfer all tokens from distributor.
            IERC20(token).transferFrom(distributor, address(this), IERC20(token).balanceOf(distributor));
        }

        nextPeriodTime = time + period;
    }

    function withdrawTokens(address token) external onlyOwner {
        require(rewardsDistributorByRewardsToken[token] == address(0), "Cannot withdaw Reward Tokens");
        require(token != address(depositToken), "Cannot withdaw Deposit Token");
        IERC20(token).transfer(owner(), IERC20(token).balanceOf(address(this)));
    }

    function _min(uint a, uint b) internal pure returns (uint) {
        return a <= b ? a : b;
    }
}

