// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "./ICore.sol";
import "./IFarm.sol";
import "./IOracle.sol";
import "./IMCV2.sol";
import "./RewardsDistributor.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

// This contract is resposible for:
// - Depositing LP receipt tokens into SpookySwap gauges.
contract Farm is IFarm, ERC20, Ownable {
    // TODO: Double check that the interfaces are the same.
    uint    public immutable epoch;
    IERC20  public immutable booToken;
    IERC20  public immutable eqlToken;
    IERC20  public immutable depositToken;
    IOracle public immutable oracle;
    ICore   public immutable core;
    IMCV2   public immutable masterChef;
    uint    public immutable spookyPoolId;
    IRewardsDistributor public immutable rewardsDistributor;

    uint public totalValueLocked;
    bool public isDisabled;

    struct RewardHistory {
        uint timestamp;
        uint eqlRewardRate;
        uint booRewardRate;
    }

    RewardHistory[] public rewardHistory;

    uint public startTime;
    uint public lastUpdateTime;
    uint public rewardPerEqlStored;
    uint public rewardPerBooStored;

    mapping(address => uint) public userRewardPerEqlPaid;
    mapping(address => uint) public userRewardPerBooPaid;
    mapping(address => uint) public eqlRewards;
    mapping(address => uint) public booRewards;

    uint internal _unlocked = 1;

    modifier lock() {
        require(_unlocked == 1, "Locked");
        _unlocked = 2;
        _;
        _unlocked = 1;
    }

    modifier updateReward(address user) {
        (uint rewardPerEql, uint rewardPerBoo) = rewardPerToken();
        rewardPerEqlStored = rewardPerEql;
        rewardPerBooStored = rewardPerBoo;
        lastUpdateTime = lastTimeRewardApplicable();

        if (user != address(0)) {
            (uint eqlEarned, uint booEarned) = earned(user);
            eqlRewards[user] = eqlEarned;
            booRewards[user] = booEarned;
            userRewardPerEqlPaid[user] = rewardPerEqlStored;
            userRewardPerBooPaid[user] = rewardPerBooStored;
        }

        _;
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

    // Over-paramaterised so mocks can be used for testing.
    constructor(
        IERC20 depositToken_,
        IERC20 eqlToken_,
        IOracle oracle_,
        uint epoch_,
        IMCV2 masterChef_,
        uint spookyPoolId_
    ) ERC20("Equilibrium Farm", "eqF") {
        core = ICore(msg.sender);
        depositToken = depositToken_;
        eqlToken = eqlToken_;
        oracle = oracle_;
        epoch = epoch_;
        masterChef = masterChef_;
        spookyPoolId = spookyPoolId_;
        booToken = IERC20(masterChef_.BOO());

        rewardsDistributor = new RewardsDistributor();
        rewardsDistributor.pushRewardToken(address(eqlToken));
        rewardsDistributor.pushRewardToken(address(booToken));
    }

    // NOTE: Reverts if no reward periods have started.
    function lastTimeRewardApplicable() public returns (uint) {
        return _min(rewardHistory[rewardHistory.length - 1].timestamp + epoch, block.timestamp);
    }

    function rewardPerToken() public returns (uint, uint) {
        if (totalSupply() == 0 || rewardHistory.length == 0) {
            return (0, 0);
        }

        uint eqlN = rewardPerEqlStored;
        uint booN = rewardPerBooStored;
        uint time = block.timestamp;
        // Prevent out of bounds read if block.timestamp is exactly on an epoch.
        uint firstEpochIndex = (lastUpdateTime - startTime) / epoch;
        uint lastEpochIndex = time % epoch == 0 ? (time - startTime - 1) / epoch : (time - startTime) / epoch;

        if (firstEpochIndex > lastEpochIndex) {
            firstEpochIndex = lastEpochIndex;
        }

        for (uint i = firstEpochIndex; i <= lastEpochIndex; ++i) {
            RewardHistory memory h = rewardHistory[i];

            if (lastUpdateTime > h.timestamp) {
                eqlN += h.eqlRewardRate * (time - lastUpdateTime) * 1e18 / totalSupply();
                booN += h.booRewardRate * (time - lastUpdateTime) * 1e18 / totalSupply();
            } else {
                eqlN += h.eqlRewardRate * (time - startTime) * 1e18 / totalSupply();
                booN += h.booRewardRate * (time - startTime) * 1e18 / totalSupply();
                time -= (time - h.timestamp);
            }
        }

        return (eqlN, booN);
    }

    function deposit(uint amount) external lock updateReward(msg.sender) {
        require(isDisabled == false, "Disabled");
        require(amount > 0, "Nothing to deposit");

        depositToken.transferFrom(msg.sender, address(this), amount);
        // When this function is called, any pending BOO will be transferred to this contract.
        masterChef.deposit(spookyPoolId, amount);
        booToken.transfer(address(rewardsDistributor), booToken.balanceOf(address(this)));
        _mint(msg.sender, amount);

        _updateTotalValueLocked();

        if (address(core) != address(0)) {
            core.update();
        }
    }

    function withdraw(uint amount) external lock updateReward(msg.sender) {
        require(amount > 0, "Nothing to withdraw");
        _burn(msg.sender, amount);
        depositToken.transfer(msg.sender, amount);
    }

    function earned(address user) public returns (uint, uint) {
        (uint rewardPerEql, uint rewardPerBoo) = rewardPerToken();
        return (
            (balanceOf(user) * (rewardPerEql - userRewardPerEqlPaid[user]) / 1e18) + eqlRewards[user],
            (balanceOf(user) * (rewardPerBoo - userRewardPerBooPaid[user]) / 1e18) + booRewards[user]
        );
    }

    function getReward() external lock updateReward(msg.sender) {
        uint reward = eqlRewards[msg.sender];
        if (reward > 0) {
            eqlRewards[msg.sender] = 0;
            eqlToken.transfer(msg.sender, reward);
        }

        reward = booRewards[msg.sender];
        if (reward > 0) {
            booRewards[msg.sender] = 0;
            booToken.transfer(msg.sender, reward);
        }
    }

    function notifyRewardAmount(uint eqlAmount, uint booAmount) external onlyOwner lock updateReward(address(0)) {
        require(msg.sender == address(core), "Not Core");

        uint time = block.timestamp;

        rewardHistory.push(RewardHistory({
            timestamp: time,
            eqlRewardRate: eqlAmount,
            booRewardRate: booAmount
        }));

        (uint rewardPerEqlStored_, uint rewardPerBooStored_) = rewardPerToken();
        rewardPerEqlStored = rewardPerEqlStored_;
        rewardPerBooStored = rewardPerBooStored_;
        lastUpdateTime = time;
    }

    function _min(uint a, uint b) internal pure returns (uint) {
        return a <= b ? a : b;
    }
}

