// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import {FixedPeriodMultiRewards} from "./FixedPeriodMultiRewards.sol";
import {IRewardsDistributor} from "./IRewardsDistributor.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {Ownable} from "openzeppelin-contracts/contracts/access/Ownable.sol";
import {Pausable} from "openzeppelin-contracts/contracts/security/Pausable.sol";
import "./IGauge.sol";
import "./IOracle.sol";
import "./Farm.sol";
import "./Token.sol";
import "./RewardsDistributor.sol";

contract Core is Ownable {
    uint32 public constant PERIOD = 30 minutes;
    uint32 public constant QUANTITY = 12;
    uint32 public constant EPOCH = PERIOD * QUANTITY;

    address    public immutable eqlToken;
    address[]  public farms;
    address[4] public activeFarms;

    mapping(address => uint) public farmIdByAddress;
    mapping(address => uint) public farmIdByDepositToken;
    mapping(address => address) public defaultDistributor;

    // Equilibrium score.
    uint32 public lastTimestamp;
    int    public score;
    int    public accumulatedScore;
    int[]  public observations;

    event UpdateScore(int value, int accumulatedScore, int score, int d0, int d1, int d2, int d3);

    constructor() {
        eqlToken = address(new Token("Equilibrium", "EQL", 1_000_000_000e18));
    }

    function deploy(address depositToken, address gauge, uint gaugeId, address oracle) public onlyOwner returns (address) {
        // Deploy farm contract.
        address farm = address(new Farm(IERC20(depositToken), IGauge(gauge), IOracle(oracle), gaugeId, EPOCH, "eqlF", "eqlF"));
        uint id = farms.length;
        farmIdByDepositToken[depositToken] = id;
        farmIdByAddress[farm] = id;
        farms.push(farm);

        // Deploy rewards distributor.
        address distributor = address(new RewardsDistributor());
        Ownable(distributor).transferOwnership(farm);
        defaultDistributor[farm] = distributor;

        return address(farm);
    }

    // TODO: Make voter or onlyOwner
    function setActiveFarms(address[4] memory addresses) public {
        for (uint i = 0; i < 4; ++i) {
            require(address(farms[farmIdByAddress[addresses[i]]]) != address(0), "Farm does not exist");
            activeFarms[i] = addresses[i];
        }
    }

    function updateScore() public {
        // TODO: Enable these
        require(address(activeFarms[0]) != address(0), "farm0 not active");
        require(address(activeFarms[1]) != address(0), "farm1 not active");
        require(address(activeFarms[2]) != address(0), "farm2 not active");
        require(address(activeFarms[3]) != address(0), "farm3 not active");

        uint32 timestamp = currentTimestamp();

        require(timestamp - lastTimestamp >= PERIOD, "Period has not yet finished");

        lastTimestamp = timestamp;

        int tvl0 = int(Farm(activeFarms[0]).totalValueLocked());
        int tvl1 = int(Farm(activeFarms[1]).totalValueLocked());
        int tvl2 = int(Farm(activeFarms[2]).totalValueLocked());
        int tvl3 = int(Farm(activeFarms[3]).totalValueLocked());

        int average = (tvl0 + tvl1 + tvl2 + tvl3) / 4;

        int delta0 = abs(average - tvl0);
        int delta1 = abs(average - tvl1);
        int delta2 = abs(average - tvl2);
        int delta3 = abs(average - tvl3);

        int value;

        if (average == 0) {
            value = 0;
        } else {
            value = (100 - (
                (delta0 * 100 / average) +
                (delta1 * 100 / average) +
                (delta2 * 100 / average) +
                (delta3 * 100 / average)) / 4);
        }

        observations.push(value);
        accumulatedScore += value;

        if (observations.length > QUANTITY) {
            accumulatedScore -= observations[observations.length - QUANTITY - 1];
            score = (score + accumulatedScore / int32(QUANTITY)) / 2;
        } else {
            score = accumulatedScore / int(observations.length);
        }

        emit UpdateScore(value, accumulatedScore, score, delta0, delta1, delta2, delta3);
    }

    function currentTimestamp() public view returns (uint32) {
        return uint32(block.timestamp % 2**32);
    }

    function getObservationsLength() public view returns (uint) {
        return observations.length;
    }

    function abs(int x) private pure returns (int) {
        return x >= 0 ? x : -x;
    }
}

