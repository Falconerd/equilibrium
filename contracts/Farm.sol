// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "./ICore.sol";
import "./IFarm.sol";
import "./IOracle.sol";
import "./IMCV2.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

// This contract is resposible for:
// - Depositing LP receipt tokens into SpookySwap gauges.
// - Distribute BOO and EQL to stakers.
// All rewards use the same schedule of `epoch`.
contract Farm is IFarm, ERC20, Ownable, Pausable {
    uint    public immutable epoch;
    IERC20  public immutable depositToken;
    IOracle public immutable oracle;
    ICore   public immutable core;
    IMCV2   public immutable masterChef;
    uint    public immutable spookyPoolId;

    address[] public rewardTokens;

    uint public totalValueLocked;

    uint public contractDeployTime;
    uint public lastRewardsUpdateTime;
    uint public nextEpochTime;

    // Keep track of rewards for each token per epoch.
    struct RewardHistory {
        uint timestamp;
        uint rewardRate;
    }

    // Reward Token => Value.
    mapping(address => RewardHistory[]) public rewardHistory;
    mapping(address => uint) public rewardPerTokenStored;
    mapping(address => address) public rewardsDistributorByRewardsToken;

    // User => Reward Token => Amount.
    mapping(address => mapping(address => uint)) public userRewardPerTokenPaid;
    mapping(address => mapping(address => uint)) public rewards;

    address private _epochStarter;
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
            address token = rewardTokens[i];
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

    // Over-paramaterised so mocks can be used for testing.
    constructor(
        IERC20 depositToken_,
        IOracle oracle_,
        uint epoch_,
        IMCV2 masterChef_,
        uint spookyPoolId_
    ) ERC20("Equilibrium Farm", "eqF") {
        core = ICore(msg.sender);
        depositToken = depositToken_;
        oracle = oracle_;
        epoch = epoch_;
        masterChef = masterChef_;
        spookyPoolId = spookyPoolId_;
    }

    function addReward(address rewardsToken_, address rewardsDistributor_) public onlyOwner {
        require(rewardsDistributorByRewardsToken[rewardsToken_] == address(0));
        rewardTokens.push(rewardsToken_);
        rewardsDistributorByRewardsToken[rewardsToken_] = rewardsDistributor_;
    }

    /* =============== VIEWS ================ */

    // NOTE: Reverts if no reward periods have started.
    function lastTimeRewardApplicable() public view returns (uint) {
        return _min(nextEpochTime - epoch, block.timestamp);
    }

    function rewardPerToken(address rewardsToken) public view returns (uint) {
        if (totalSupply() == 0 || rewardHistory[rewardsToken].length == 0) {
            return (0);
        }

        uint n = rewardPerTokenStored[rewardsToken];
        uint time = block.timestamp;
        // Prevent out of bounds read if block.timestamp is exactly on an epoch.
        uint firstEpochIndex = (lastRewardsUpdateTime - contractDeployTime) / epoch;
        uint lastEpochIndex = time % epoch == 0 ? (time - contractDeployTime - 1) / epoch : (time - contractDeployTime) / epoch;

        if (firstEpochIndex > lastEpochIndex) {
            firstEpochIndex = lastEpochIndex;
        }

        for (uint i = firstEpochIndex; i <= lastEpochIndex; ++i) {
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

    function setRewardsDistributor(address rewardsToken, address rewardsDistributor) external onlyOwner {
        rewardsDistributorByRewardsToken[rewardsToken] = rewardsDistributor;
    }

    function deposit(uint amount) external whenNotPaused lock updateReward(msg.sender) {
        require(amount > 0, "Nothing to deposit");

        depositToken.transferFrom(msg.sender, address(this), amount);
        // When this function is called, any pending BOO will be transferred to this contract.
        // TODO: Transfer the BOO et al straight to the BOO et al distributor.
        masterChef.deposit(spookyPoolId, amount);
        _mint(msg.sender, amount);

        _updateTotalValueLocked();

        if (address(core) != address(0)) {
            core.update();
        }
    }

    function withdraw(uint amount) external lock updateReward(msg.sender) {
        require(amount > 0, "Nothing to withdraw");
        _burn(msg.sender, amount);
        // When this function is called, any pending BOO will be transferred to this contract.
        masterChef.withdraw(spookyPoolId, amount);
        depositToken.transfer(msg.sender, amount);

        _updateTotalValueLocked();
    }

    function getReward() external lock updateReward(msg.sender) {
        for (uint i = 0; i < rewardTokens.length; ++i) {
            address rewardsToken = rewardTokens[i];
            uint reward = rewards[msg.sender][rewardsToken];
            if (reward > 0) {
                rewards[msg.sender][rewardsToken] = 0;
                IERC20(rewardsToken).transfer(msg.sender, reward);
            }
        }
    }

    /* ================ RESTRICTED FUNCTIONS ================ */

    function setEpochStarter(address account) external onlyOwner {
        _epochStarter = account;
    }

    function startNextEpoch() external updateReward(address(0)) {
        require(msg.sender == _epochStarter);

        uint time = block.timestamp;

        require(time >= nextEpochTime, "Epoch has not yet finished");

        for (uint i = 0; i < rewardTokens.length; ++i) {
            address token = rewardTokens[i];
            address distributor = rewardsDistributorByRewardsToken[token];

            rewardHistory[token].push(RewardHistory({
                timestamp: time,
                rewardRate: IERC20(token).balanceOf(distributor)
            }));
            rewardPerTokenStored[token] = rewardPerToken(token);

            // Always transfer all tokens from distributor.
            IERC20(token).transferFrom(distributor, address(this), IERC20(token).balanceOf(distributor));
        }

        nextEpochTime = time + epoch;
    }

    function _min(uint a, uint b) internal pure returns (uint) {
        return a <= b ? a : b;
    }

    function _updateTotalValueLocked() internal {
        (uint price0, uint price1) = oracle.getPrices();
        if (totalSupply() == 0) {
            totalValueLocked = 0;
        } else {
            (uint balance0, uint balance1) = oracle.getBalances(totalSupply());
            totalValueLocked = price0 * balance0 + price1 * balance1;
        }
    }
}

