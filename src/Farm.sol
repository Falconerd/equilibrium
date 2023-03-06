// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import {FixedPeriodMultiRewards} from "./FixedPeriodMultiRewards.sol";
import {IRewardsDistributor} from "./IRewardsDistributor.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {Ownable} from "openzeppelin-contracts/contracts/access/Ownable.sol";
import {Pausable} from "openzeppelin-contracts/contracts/security/Pausable.sol";
import "./ICore.sol";
import "./IGauge.sol";
import "./IOracle.sol";
import "./RewardsDistributor.sol";

// This contract take in spLP tokens from SpookySwap
// and deposits then into a gauge.
contract Farm is FixedPeriodMultiRewards {
    address public immutable core;
    // Since some rewards are auto-claimed on user interaction
    // they need to be sent to the rewardsDistributor.
    address[] public autoClaimedRewards;
    mapping(address => uint) public rewardIndex;
    mapping(address => uint) public amountBefore;
    mapping(address => bool) public autoClaimedRewardsAdded;

    // Time Weighted Average TVL.
    IOracle public oracle;
    uint public totalValueLocked;
    uint public constant PERIOD = 30 minutes;
    uint public constant QUANTITY = 12;
    uint public lastTimestamp;
    int public accumulatedValue;
    int[] public values;

    constructor(
        IERC20 depositToken_,
        IGauge gauge_,
        IOracle oracle_,
        uint gaugeId_,
        uint period_,
        string memory tokenName_,
        string memory tokenSymbol_
    ) FixedPeriodMultiRewards(depositToken_, gauge_, gaugeId_, period_, tokenName_, tokenSymbol_) {
        core = msg.sender;
        oracle = oracle_;
    }

    /* ================ MUTATIVE FUNCTIONS ================ */

    function addAutoClaimedReward(address token) external onlyOwner {
        require(rewardsDistributor[token] != address(0), "No RewardsDistributor set up for this reward token");
        require(!autoClaimedRewardsAdded[token], "Token has already been added");
        rewardIndex[token] = autoClaimedRewards.length;
        autoClaimedRewardsAdded[token] = true;
        autoClaimedRewards.push(token);
    }

    // BOO is always transferred automatically without claiming.
    function _beforeDeposit() internal override {
        for (uint i = 0; i < autoClaimedRewards.length; ++i) {
            address token = autoClaimedRewards[i];
            amountBefore[token] = IERC20(token).balanceOf(address(this));
        }
    }

    function _afterDeposit() internal override {
        _transferRewards();
        _updateTotalValueLocked();
        ICore(core).updateScore();
    }

    function _beforeWithdraw() internal override {
        for (uint i = 0; i < autoClaimedRewards.length; ++i) {
            address token = autoClaimedRewards[i];
            amountBefore[token] = IERC20(token).balanceOf(address(this));
        }
    }

    function _afterWithdraw() internal override {
        _transferRewards();
        _updateTotalValueLocked();
        ICore(core).updateScore();
    }

    function _transferRewards() private {
        for (uint i = 0; i < autoClaimedRewards.length; ++i) {
            address token = autoClaimedRewards[i];
            uint amountAfter = IERC20(token).balanceOf(address(this));
            uint difference = amountAfter - amountBefore[token];
            uint rewarderBalance = IERC20(token).balanceOf(rewardsDistributor[address(token)]);
            IERC20(token).transfer(rewardsDistributor[address(token)], difference);
            IRewardsDistributor(rewardsDistributor[address(token)])
                .setNextAmountToDistribute(address(token), rewarderBalance + difference);
        }
    }

    function _updateTotalValueLocked() private {
        uint timestamp = block.timestamp;
        if (timestamp - lastTimestamp >= PERIOD) {
            int value = int(IOracle(oracle).consult(address(depositToken), totalSupply()));

            values.push(value);
            accumulatedValue += value;
            lastTimestamp = timestamp;
            
            if (values.length > QUANTITY) {
                accumulatedValue -= values[values.length - QUANTITY - 1];
                totalValueLocked = uint((value + accumulatedValue / int(QUANTITY)) / 2);
            } else {
                totalValueLocked = uint(accumulatedValue / int(values.length));
            }
        }
    }

    /* ================ VIEW FUNCTIONS ================ */

    function autoClaimedRewardsLength() external view returns (uint) {
        return autoClaimedRewards.length;
    }
}
