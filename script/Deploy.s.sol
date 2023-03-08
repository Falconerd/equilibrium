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
        uint deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        address houseToken = address(new Token());
        address stakedToken = address(new StakedToken(houseToken));
        address core = address(new Core(houseToken, stakedToken, address(0xBa466678Cb82855884a7c49184FCE9B3b7391659)));
        address fakeLP0 = address(new MockPair("FakeLP0", "FakeLP0"));
        address fakeLP1 = address(new MockPair("FakeLP1", "FakeLP1"));
        address fakeLP2 = address(new MockPair("FakeLP2", "FakeLP2"));
        address fakeLP3 = address(new MockPair("FakeLP3", "FakeLP3"));
        address oracle = address(new MockOracle());

        bytes32 salt = 0xdd2FB1EE6f83F3f072a6489f4A6DBaFa92FB1EE6f83F3f072a6489f4A6DBaFa9;
        address farm0 = Core(core).deployFarm(salt, fakeLP0, address(0), 0, oracle);
        address farm1 = Core(core).deployFarm(salt, fakeLP1, address(0), 0, oracle);
        address farm2 = Core(core).deployFarm(salt, fakeLP2, address(0), 0, oracle);
        address farm3 = Core(core).deployFarm(salt, fakeLP3, address(0), 0, oracle);

        vm.stopBroadcast();
    }
}
