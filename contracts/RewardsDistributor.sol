// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "./IRewardsDistributor.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

// Just put rewards here to keep the Farms clean.
// It simplifies the math.
contract RewardsDistributor is IRewardsDistributor, Ownable {
    address[] public rewardTokens;
    mapping(address => uint) public balanceLastEpoch;

    function pushRewardToken(address token) public onlyOwner {
        rewardTokens.push(token);
    }
}
