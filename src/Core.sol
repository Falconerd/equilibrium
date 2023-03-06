// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import {IFixedPeriodMultiRewards} from "./IFixedPeriodMultiRewards.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {Ownable} from "openzeppelin-contracts/contracts/access/Ownable.sol";
import "./IFarm.sol";

contract Core is Ownable {
    using UQ112x112 for uint224;

    uint32 public constant PERIOD = 30 minutes;
    uint32 public constant QUANTITY = 12;
    uint32 public constant EPOCH = PERIOD * QUANTITY;

    address[]  public farms;
    address[4] public activeFarms;

    mapping(address => uint) public farmIdByAddress;
    mapping(address => uint) public farmIdByDepositToken;

    // Equilibrium score.
    uint32 public lastTimestamp;
    int    public score;
    int    public accumulatedScore;
    int[]  public observations;

    // Emissions.
    uint8 public constant SHARES_FARMS = 18;
    uint8 public constant SHARES_VAULT = 23;
    uint8 public constant SHARES_ADMIN =  5;

    uint32 public constant MIN_TOTAL_EMISSIONS_PERIOD = 52 weeks;
    uint32 public constant MAX_TOTAL_EMISSIONS_PERIOD = 104 weeks;

    uint112 public immutable minEmissionsPerEpoch;
    uint112 public immutable maxEmissionsPerEpoch;

    address public immutable eqlToken;
    address public immutable xEqlToken;
    /* address public immutable vEqlToken; */
    address public immutable admin;

    uint[] public epochs;

    // Voting.
    uint32 public constant VOTE_DURATION = 6 days;
    uint32 public votesHeld;
    bytes32 public voteId;
    // UUID => Farm => Count.
    mapping(bytes32 => mapping(address => uint)) public votes;
    // UUID => User => Unused Votes (measured in xEQL tokens).
    mapping(bytes32 => mapping(address => uint)) public votesRemaining;

    event FarmCreated(address indexed token, uint);
    event ActiveFarmsSet(address, address, address, address);

    event UpdateScore(int value, int accumulatedScore, int score, int d0, int d1, int d2, int d3);

    constructor(address eqlToken_, address xEqlToken_) {
        uint eqlMaxSupply = 1_000_000_000e18;
        eqlToken = eqlToken_;
        xEqlToken = xEqlToken_;
        /* vEqlToken = address(new VoteLockedToken(xEqlToken)); */
        admin = msg.sender;

        minEmissionsPerEpoch = uint112(eqlMaxSupply / MAX_TOTAL_EMISSIONS_PERIOD) / EPOCH;
        maxEmissionsPerEpoch = uint112(eqlMaxSupply / MIN_TOTAL_EMISSIONS_PERIOD) / EPOCH;
    }

    function register(address farm, address depositToken, address distributor) public onlyOwner returns (address) {
        // Add newly deployed farm contract.
        uint id = farms.length;
        farmIdByDepositToken[depositToken] = id;
        farmIdByAddress[farm] = id;
        farms.push(farm);

        emit FarmCreated(farm, farms.length);

        return address(farm);
    }

    function newVotingRound() public {
        /* require(!IVoteLockedToken(xEqlToken).inProgress(), "Voting round still active"); */
        /*  */
        /* (address f0, address f1, address f2, address f3) = IVoteLockedToken(vEqlToken).topVoted(); */
        /*  */
        /* require(address(farms[farmIdByAddress[f0]]) != address(0), "Farm does not exist"); */
        /* require(address(farms[farmIdByAddress[f1]]) != address(0), "Farm does not exist"); */
        /* require(address(farms[farmIdByAddress[f2]]) != address(0), "Farm does not exist"); */
        /* require(address(farms[farmIdByAddress[f3]]) != address(0), "Farm does not exist"); */
        /*  */
        /* activeFarms[0] = f0; */
        /* activeFarms[1] = f1; */
        /* activeFarms[2] = f2; */
        /* activeFarms[3] = f3; */
    }

    function setActiveFarms(address[4] memory addresses) public onlyOwner {
        for (uint i = 0; i < 4; ++i) {
            require(address(farms[farmIdByAddress[addresses[i]]]) != address(0), "Farm does not exist");
            activeFarms[i] = addresses[i];
        }
    }

    function newEpoch() external {
        uint timestamp = block.timestamp;
        require(timestamp >= epochs[epochs.length - 1] + EPOCH, "Epoch not finished");

        updateScore();

        uint emissionsBonus = score > 0 ? uint(score) : uint(0);
        uint224 emissions = minEmissionsPerEpoch + (UQ112x112.encode(maxEmissionsPerEpoch - minEmissionsPerEpoch)
        // Magic number to get back uint precision of 18 without overflowing.
                            .uqdiv(uint112(1e20 / emissionsBonus)) / 5192296858534827);

        uint rewardsFarms = emissions / (1e20 / uint(SHARES_FARMS) * 1e18);
        uint rewardsVault = emissions / (1e28 / uint(SHARES_VAULT) * 1e18);
        uint rewardsAdmin = emissions / (1e20 / uint(SHARES_ADMIN) * 1e18);

        epochs.push(timestamp);

        // Transfer to farm rewards distributor.
        IERC20(eqlToken).transfer(IFixedPeriodMultiRewards(activeFarms[0]).rewardsDistributor(eqlToken), rewardsFarms);
        IERC20(eqlToken).transfer(IFixedPeriodMultiRewards(activeFarms[1]).rewardsDistributor(eqlToken), rewardsFarms);
        IERC20(eqlToken).transfer(IFixedPeriodMultiRewards(activeFarms[2]).rewardsDistributor(eqlToken), rewardsFarms);
        IERC20(eqlToken).transfer(IFixedPeriodMultiRewards(activeFarms[3]).rewardsDistributor(eqlToken), rewardsFarms);

        IERC20(eqlToken).transfer(xEqlToken, rewardsVault);
        IERC20(eqlToken).transfer(admin, rewardsAdmin);
    }

    function updateScore() public {
        require(address(activeFarms[0]) != address(0), "farm0 not active");
        require(address(activeFarms[1]) != address(0), "farm1 not active");
        require(address(activeFarms[2]) != address(0), "farm2 not active");
        require(address(activeFarms[3]) != address(0), "farm3 not active");
        
        uint32 timestamp = currentTimestamp();
        
        // Don't require because then it reverts deposits and withdrawals.
        if (timestamp - lastTimestamp >= PERIOD) {
            lastTimestamp = timestamp;
        
            int tvl0 = int(IFarm(activeFarms[0]).totalValueLocked());
            int tvl1 = int(IFarm(activeFarms[1]).totalValueLocked());
            int tvl2 = int(IFarm(activeFarms[2]).totalValueLocked());
            int tvl3 = int(IFarm(activeFarms[3]).totalValueLocked());
        
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

// From Uniswap V2
library UQ112x112 {
    uint224 constant Q112 = 2**112;

    // encode a uint112 as a UQ112x112
    function encode(uint112 y) internal pure returns (uint224 z) {
        z = uint224(y) * Q112; // never overflows
    }

    // divide a UQ112x112 by a uint112, returning a UQ112x112
    function uqdiv(uint224 x, uint112 y) internal pure returns (uint224 z) {
        z = x / uint224(y);
    }
}
