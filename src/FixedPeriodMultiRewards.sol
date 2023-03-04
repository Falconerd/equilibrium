// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import {ERC20} from "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {Ownable} from "openzeppelin-contracts/contracts/access/Ownable.sol";
import {Pausable} from "openzeppelin-contracts/contracts/security/Pausable.sol";

// THIS CONTRACT IS WIP AND HAS BUGS, DO NOT USE UNTIL THIS NOTICE IS REMOVED
// Modified MultiRewards contract to use a fixed-time period.
// - Reward Tokens require a Distributor contract that has allows this
//   contract to spend the Reward Token.
// - Each new Period, all Reward Tokens are sent from each distributor
//   to this contract, and the rewardRate is set to the totalSupply of
//   the distributor before sending.
contract FixedPeriodMultiRewards is ERC20, Ownable, Pausable {
    uint   public immutable period;
    IERC20 public immutable depositToken;

    event Log(uint, uint);

    uint public contractDeployTime;
    uint public lastRewardsUpdateTime;
    uint public nextPeriodTime;

    // Keep track of rewards for each token.
    IERC20[] public rewardTokens;

    // Reward Token => Value.
    mapping(address => uint) public rewardRate;
    mapping(address => uint) public lastUpdateTime;
    mapping(address => uint) public rewardPerTokenStored;
    mapping(address => address) public rewardsDistributor;

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
            lastUpdateTime[token] = lastTimeRewardApplicable();
            if (user != address(0)) {
                rewards[user][token] = earned(user, token);
                userRewardPerTokenPaid[user][token] = rewardPerTokenStored[token];
            }
        }
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
        require(rewardsDistributor[rewardsToken_] == address(0));
        rewardTokens.push(IERC20(rewardsToken_));
        rewardsDistributor[rewardsToken_] = rewardsDistributor_;
    }

    /* =============== VIEWS ================ */

    function rewardTokensLength() external view returns (uint) {
        return rewardTokens.length;
    }

    function lastTimeRewardApplicable() public view returns (uint) {
        return _min(block.timestamp, nextPeriodTime);
    }

    function rewardPerToken(address rewardsToken) public view returns (uint) {
        if (totalSupply() == 0) {
            return rewardPerTokenStored[rewardsToken];
        }

        return rewardPerTokenStored[rewardsToken] + (
            ((lastTimeRewardApplicable() - lastUpdateTime[rewardsToken]) * rewardRate[rewardsToken] * 1e18) / totalSupply()
        );
    }

    function earned(address user, address rewardsToken) public view returns (uint) {
        return (balanceOf(user) * (rewardPerToken(rewardsToken) - userRewardPerTokenPaid[user][rewardsToken]) / 1e18) + rewards[user][rewardsToken];
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

    /* ================ RESTRICTED FUNCTIONS ================ */

    function setRewardsDistributor(address rewardsToken, address rewardsDistributor_) external onlyOwner {
        rewardsDistributor[rewardsToken] = rewardsDistributor_;
    }

    function setPeriodStarter(address account) external onlyOwner {
        _periodStarter = account;
    }

    function notifyRewardAmounts(address[] calldata rewardsTokens, uint[] calldata amounts) external updateReward(address(0)) {
        require(msg.sender == _periodStarter);
        require(rewardsTokens.length == amounts.length);

        for (uint i = 0; i < rewardsTokens.length; ++i) {
            address token = rewardsTokens[i];
            uint amount = amounts[i];

            IERC20(token).transferFrom(rewardsDistributor[token], address(this), amount);
            if (block.timestamp >= nextPeriodTime) {
                rewardRate[token] = amount / period;
            } else {
                uint remainingTime = nextPeriodTime - block.timestamp;
                uint remainingTokens = remainingTime * rewardRate[token];
                rewardRate[token] = (amount + remainingTokens) / period;
            }

            lastUpdateTime[token] = block.timestamp;
        }

        nextPeriodTime = block.timestamp + period;
        lastRewardsUpdateTime = block.timestamp;
    }

    function withdrawTokens(address token) external onlyOwner {
        require(rewardsDistributor[token] == address(0), "Cannot withdaw Reward Tokens");
        require(token != address(depositToken), "Cannot withdaw Deposit Token");
        IERC20(token).transfer(owner(), IERC20(token).balanceOf(address(this)));
    }

    function _min(uint a, uint b) internal pure returns (uint) {
        return a <= b ? a : b;
    }
}

