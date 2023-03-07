// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import {ERC20, IERC20} from "./ERC20.sol";
import "./Ownable.sol";
import "./Pausable.sol";
import {IDistributor} from "./Distributor.sol";
import {FixedPeriodMultiRewards, IGauge} from "./FixedPeriodMultiRewards.sol";

interface IOracle {
    function consult(address token) external returns (uint);
}

interface IEquilibrium {
    function updateScore() external;
}

contract Farm is FixedPeriodMultiRewards {
    address public immutable equilibrium;

    // Auto-Claimed rewards (like BOO).
    address[] public autoClaimedRewards;
    mapping(address => uint) public rewardIndex;
    mapping(address => uint) public amountBefore;

    // Time weighted average TVL.
    address public oracle;
    uint public totalValueLocked;
    uint public constant PERIOD = 30 minutes;
    uint public constant QUANTITY = 12;
    uint public lastTimestamp;
    int public accumulatedValue;
    int[] public values;

    constructor(address equilibrium_, address stake_, address gauge_, uint gaugeId_)
        FixedPeriodMultiRewards(stake_, gauge_, gaugeId_, "Symmetrix Farm", "fSMX") {
        equilibrium = equilibrium_;
    }

    function _beforeSupplyChange() internal override {
        for (uint i = 0; i < autoClaimedRewards.length; ++i) {
            address token = autoClaimedRewards[i];
            amountBefore[token] = IERC20(token).balanceOf(address(this));
        }
    }

    function _afterSupplyChange() internal override {
        _transferRewards();
        _updateTotalValueLocked();
        IEquilibrium(equilibrium).updateScore();
    }

    function _transferRewards() private {
        for (uint i = 0; i < autoClaimedRewards.length; ++i) {
            address token = autoClaimedRewards[i];
            uint amountAfter = IERC20(token).balanceOf(address(this));
            uint difference = amountAfter - amountBefore[token];
            uint distributorBalance = IERC20(token).balanceOf(distributor[token]);
            IERC20(token).transfer(distributor[token], difference);
            IDistributor(distributor[token])
                .setNextAmountToDistribute(token, distributorBalance + difference);
        }
    }

    function _updateTotalValueLocked() private {
        uint timestamp = block.timestamp;
        if (timestamp - lastTimestamp >= PERIOD) {
            int value = int(IOracle(oracle).consult(address(stake)));

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
}
