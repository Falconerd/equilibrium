// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "./Ownable.sol";
import "./Farm.sol";
import "./Token.sol";
import "hardhat/console.sol";

contract Core is Ownable {
    uint32 public constant PERIOD = 30 minutes;
    uint32 public constant QUANTITY = 12;
    uint32 public constant EPOCH = PERIOD * QUANTITY;

    Farm public farm0;
    Farm public farm1;
    Farm public farm2;
    Farm public farm3;

    Farm[] public farms;

    Token immutable rewardsToken;

    // Equilibrium Score.
    uint32 public lastTimestamp;
    int public score;
    int public accumulatedScore;
    int[] public observations;

    event UpdateScore(int value, int accumulatedScore, int score, int d0, int d1, int d2, int d3);

    constructor() {
        rewardsToken = new Token("Equilibrium", "EQL", 18, 0);
    }

    // TODO: Gauge
    // TODO: concrete types
    function deployFarm(address stakingToken, address oracle) public onlyOwner returns (address) {
        Farm farm = new Farm(stakingToken, address(rewardsToken), EPOCH, oracle);
        return address(farm);
    }

    function depositIntoFarm(address farmAddress, uint amount) public {
    }

    // todo: remove this function.
    function setActiveFarms(Farm farm0_, Farm farm1_, Farm farm2_, Farm farm3_) public {
        farm0 = farm0_;
        farm1 = farm1_;
        farm2 = farm2_;
        farm3 = farm3_;
    }

    function update() public {
        // TODO: Enable these
        //require(farm0 != Farm(address(0)), "farm0 not deployed");
        //require(farm1 != Farm(address(0)), "farm1 not deployed");
        //require(farm2 != Farm(address(0)), "farm2 not deployed");
        //require(farm3 != Farm(address(0)), "farm3 not deployed");

        uint32 timestamp = currentTimestamp();

        if (timestamp - lastTimestamp >= PERIOD) {
            lastTimestamp = timestamp;


            int tvl0 = int(farm0.totalValueLocked());
            int tvl1 = int(farm1.totalValueLocked());
            int tvl2 = int(farm2.totalValueLocked());
            int tvl3 = int(farm3.totalValueLocked());

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
    }

    function currentTimestamp() public returns (uint32) {
        return uint32(block.timestamp % 2**32);
    }

    function getObservationsLength() public view returns (uint) {
        return observations.length;
    }

    function abs(int x) private pure returns (int) {
        return x >= 0 ? x : -x;
    }
}
