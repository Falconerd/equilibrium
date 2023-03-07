// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import {ERC20} from "./ERC20.sol";
import "./Ownable.sol";
import "./Pausable.sol";
import {IDistributor} from "./Distributor.sol";

interface IGauge {
    function deposit(uint id, uint amount) external;
    function withdraw(uint id, uint amount) external;
}

contract FixedPeriodMultiRewards is ERC20, Ownable, Pausable {
    uint public constant EPOCH = 6 hours;
    address public immutable stake;
    address public immutable gauge;
    uint public immutable gaugeId;

    uint public immutable contractDeployTime;
    uint public nextEpochTime;

    address[] public rewardTokens;
    mapping(address => bool) public isRewardToken;

    // Reward Token => Value.
    mapping(address => uint) public rewardRate;
    mapping(address => uint) public lastUpdateTime;
    mapping(address => uint) public rewardPerTokenStored;
    mapping(address => address) public distributor;

    // User => Reward Token => Amount.
    mapping(address => mapping(address => uint)) public userRewardPerTokenPaid;
    mapping(address => mapping(address => uint)) public rewards;

    uint internal _unlocked = 1;

    // MODIFIERS

    modifier lock() {
        _lockBefore();
        _;
        _lockAfter();
    }

    modifier updateReward(address user) {
        _updateReward(user);
        _;
    }

    // INIT

    event EpochStarted();

    constructor(address stake_, address gauge_, uint gaugeId_, string memory name_, string memory symbol_) ERC20(name_, symbol_) {
        stake = stake_;
        gauge = gauge_;
        gaugeId = gaugeId_;
        contractDeployTime = block.timestamp;

        if (gauge != address(0)) {
            ERC20(stake_).approve(gauge, type(uint).max);
        }
    }

    function registerRewardToken(address token, address distributor_) public onlyOwner {
        require(!isRewardToken[token], "Farm: Token is already a reward token");
        rewardTokens.push(token);
        distributor[token] = distributor_;
    }

    // VIEWS

    function lastTimeRewardApplicable() public view returns (uint) {
        return _min(block.timestamp, nextEpochTime);
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

    // MUTATIVE

    function deposit(uint amount) whenNotPaused lock public {
        require(amount > 0, "Nothing to deposit");
        _beforeSupplyChange();
        ERC20(stake).transferFrom(_msgSender(), address(this), amount);
        if (gauge != address(0)) {
            IGauge(gauge).deposit(gaugeId, amount);
        }
        _mint(_msgSender(), amount);
        _afterSupplyChange();
    }

    function withdraw(uint amount) public lock updateReward(msg.sender) {
        require(amount > 0, "Nothing to withdraw");
        _beforeSupplyChange();
        _burn(msg.sender, amount);
        if (gauge != address(0)) {
            IGauge(gauge).withdraw(gaugeId, amount);
        }
        ERC20(stake).transfer(msg.sender, amount);
        _afterSupplyChange();
    }

    function getReward() external lock updateReward(_msgSender()) {
        for (uint i = 0; i < rewardTokens.length; ++i) {
            address rewardsToken = rewardTokens[i];
            uint reward = rewards[_msgSender()][rewardsToken];
            if (reward > 0) {
                rewards[_msgSender()][rewardsToken] = 0;
                ERC20(rewardsToken).transfer(_msgSender(), reward);
            }
        }
    }

    // RESTRICTED
    
    function setDistributor(address rewardsToken, address distributor_) external onlyOwner {
        require(distributor[rewardsToken] != address(0), "use addReward");
        distributor[rewardsToken] = distributor_;
    }

    function startNextEpoch() external onlyOwner updateReward(address(0)) {
        for (uint i = 0; i < rewardTokens.length; ++i) {
            address token = rewardTokens[i];
            uint amount = IDistributor(distributor[token]).nextAmountToDistribute(token);

            ERC20(token).transferFrom(distributor[token], address(this), amount);

            if (block.timestamp >= nextEpochTime) {
                rewardRate[token] = amount / EPOCH;
            } else {
                uint remainingTime = nextEpochTime - block.timestamp;
                uint remainingTokens = remainingTime * rewardRate[token];
                rewardRate[token] = (amount + remainingTokens) / EPOCH;
            }

            lastUpdateTime[token] = block.timestamp;
        }

        nextEpochTime = block.timestamp + EPOCH;
    }

    function withdrawTokens(address token) external onlyOwner {
        require(!isRewardToken[token], "Cannot withdaw Reward Tokens");
        require(token != stake, "Cannot withdaw Deposit Token");
        ERC20(token).transfer(owner(), ERC20(token).balanceOf(address(this)));
    }

    function rewardTokensLength() external view returns (uint) {
        return rewardTokens.length;
    }

    function _beforeSupplyChange() internal virtual {
    }

    function _afterSupplyChange() internal virtual {
    }

    function _min(uint a, uint b) internal pure returns (uint) {
        return a <= b ? a : b;
    }

    function _updateReward(address user) private {
        for (uint i = 0; i < rewardTokens.length; ++i) {
            address token = rewardTokens[i];
            rewardPerTokenStored[token] = rewardPerToken(token);
            lastUpdateTime[token] = lastTimeRewardApplicable();
            if (user != address(0)) {
                rewards[user][token] = earned(user, token);
                userRewardPerTokenPaid[user][token] = rewardPerTokenStored[token];
            }
        }
    }

    function _lockBefore() private {
        require(_unlocked == 1, "Locked");
        _unlocked = 2;
    }

    function _lockAfter() private {
        _unlocked = 1;
    }
}

