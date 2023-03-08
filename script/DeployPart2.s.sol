
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
        address core = address(0x3e78D6D84D168AF4015Db54BD78Afb5FDf406723);
        address houseToken = address(0x7C52F587013Ed658e3A3Ebf1c3D02965A3c4F9cF);
        address stakedToken = address(0x387e19448924Bca0e3730bd41839a8113d8c9668);
        address farm0 = address(0xabb42729E07f578000D438ACa89BB881dAcE778E);
        address farm1 = address(0xFe0FdB358878691a4c8bE3E7FDD2dA83f7d4Fd71);
        address farm2 = address(0xb5CfC2Fa285f450C138a011523a1e9B5fBbFC2A7);
        address farm3 = address(0x2cb834140c4b3bd388632731E47d1Ed62a22740a);

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
