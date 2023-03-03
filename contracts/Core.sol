// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "./EQL.sol";
import "./IFarm.sol";
import "./IOracle.sol";
import "./Farm.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

// This contract is resposible for:
// - Deploying new farms.
// - Keeping track of the Equilibrium Score.
// - Sending EQL Rewards to farms.

contract Core is Ownable {
    uint32 public constant PERIOD = 30 minutes;
    uint32 public constant QUANTITY = 12;
    uint32 public constant EPOCH = PERIOD * QUANTITY;

    IERC20  public immutable eqlToken;
    Farm[]  public farms;
    Farm[4] public activeFarms;

    mapping(address => uint) public farmIdByAddress;
    mapping(address => uint) public farmIdByDepositToken;

    // Equilibrium score.
    uint32 public lastTimestamp;
    int    public score;
    int    public accumulatedScore;
    int[]  public observations;

    event UpdateScore(int value, int accumulatedScore, int score, int d0, int d1, int d2, int d3);

    constructor() {
        eqlToken = new EQL();
    }

    function deploy(address depositToken, address oracle, address masterChef, uint spookyPoolId) public onlyOwner returns (address) {
        Farm farm = new Farm(IERC20(depositToken), IOracle(oracle), EPOCH, IMCV2(masterChef), spookyPoolId);
        farmIdByDepositToken[depositToken] = farms.length;
        farmIdByAddress[address(farm)] = farms.length;
        farms.push(farm);
        return address(farm);
    }

    // TODO: Make voter or onlyOwner
    function setActiveFarms(address[4] memory addresses) public {
        for (uint i = 0; i < 4; ++i) {
            require(address(farms[farmIdByAddress[addresses[i]]]) != address(0), "Farm does not exist");
            activeFarms[i] = Farm(addresses[i]);
        }
    }

    function updateScore() public {
        // TODO: Enable these
        require(address(activeFarms[0]) != address(0), "farm0 not deployed");
        require(address(activeFarms[1]) != address(0), "farm1 not deployed");
        require(address(activeFarms[2]) != address(0), "farm2 not deployed");
        require(address(activeFarms[3]) != address(0), "farm3 not deployed");

        uint32 timestamp = currentTimestamp();

        require(timestamp - lastTimestamp >= PERIOD, "Period has not yet finished");

        lastTimestamp = timestamp;

        int tvl0 = int(activeFarms[0].totalValueLocked());
        int tvl1 = int(activeFarms[1].totalValueLocked());
        int tvl2 = int(activeFarms[2].totalValueLocked());
        int tvl3 = int(activeFarms[3].totalValueLocked());

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
