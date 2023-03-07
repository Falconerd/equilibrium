// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import {Ownable} from "./Ownable.sol";

contract Deployer is Ownable {
    event Deployed(address addr);

    function deploy(bytes32 salt, bytes memory code) onlyOwner public {
        address addr;
        assembly {
            addr := create2(0, add(code, 0x20), mload(code), salt)
            if iszero(extcodesize(addr)) {
                revert(0, 0)
            }
        }
        emit Deployed(addr);
    }

    function setOwner(address user, address c) onlyOwner public {
        Ownable(c).transferOwnership(user);
    }
}
