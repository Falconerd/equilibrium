
// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import "forge-std/Script.sol";
import {IERC20} from "../src/ERC20.sol";
import {Ownable} from "../src/Ownable.sol";
import {Token} from "../src/Token.sol";
import {StakedToken} from "../src/StakedToken.sol";
import {Core} from "../src/Core.sol";
import {MockPair} from "../src/MockPair.sol";
import {MockOracle} from "../src/MockOracle.sol";
import {Distributor} from "../src/Distributor.sol";
import {Farm} from "../src/Farm.sol";
import {FixedPeriodMultiRewards} from "../src/FixedPeriodMultiRewards.sol";

contract Deploy is Script {
    function run() external {
        address core = address(0xE9D4fb18527f008d135d26808f07Ae22DCac777E);
        address houseToken = address(0xB1f93Ea63E463e0796264a529732E89683ab9810);
        address stakedToken = address(0x2905362B80CAc5c69eEea9e671e77972A710CfCC);
        address farm0 = address(0x759e8A13C68c1E4885d08328BeC19dE320b4E615);
        address farm1 = address(0xC8985E245D3e701539CCDd2bd77E4376b6200f30);
        address farm2 = address(0x0e1d90C374281789010fB6e9E2f7B974f69FA0E2);
        address farm3 = address(0x7BdCa39C40a418c510F8380Bb91714e4A616ac60);

        uint deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        IERC20(houseToken).transfer(core, IERC20(houseToken).totalSupply());

        address distributor0 = address(new Distributor(farm0));
        address distributor1 = address(new Distributor(farm1));
        address distributor2 = address(new Distributor(farm2));
        address distributor3 = address(new Distributor(farm3));

        Core(core).registerRewardToken(farm0, houseToken, distributor0);
        Core(core).registerRewardToken(farm1, houseToken, distributor1);
        Core(core).registerRewardToken(farm2, houseToken, distributor2);
        Core(core).registerRewardToken(farm3, houseToken, distributor3);

        Distributor(distributor0).approve(farm0, houseToken, type(uint).max);
        Distributor(distributor1).approve(farm1, houseToken, type(uint).max);
        Distributor(distributor2).approve(farm2, houseToken, type(uint).max);
        Distributor(distributor3).approve(farm3, houseToken, type(uint).max);

        address distributorStaked = address(new Distributor(stakedToken));
        Farm(stakedToken).registerRewardToken(houseToken, distributorStaked);

        Distributor(distributorStaked).approve(stakedToken, houseToken, type(uint).max);
        Ownable(stakedToken).transferOwnership(core);

        Core(core).setActiveFarms([farm0, farm1, farm2, farm3]);
        Core(core).startEpoch();

        vm.stopBroadcast();
    }
}
