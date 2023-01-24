// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import "./Ownable.sol";

contract TimeWeightedAverage is Ownable {
    uint32 public immutable period;
    uint32 public immutable quantity;
    uint32 public last_timestamp;
    int public last_value;
    int public accumulated_value;
    int[] public values;

    constructor(uint32 _period, uint32 _quantity) {
        owner = msg.sender;
        period = _period;
        quantity = _quantity;
    }

    function receive_value(int value) public is_owner {
        uint32 timestamp = uint32(block.timestamp % 2**32);

        if (timestamp - last_timestamp >= period) {
            last_timestamp = timestamp;

            values.push(value);
            accumulated_value += value;

            if (values.length > quantity) {
                accumulated_value -= values[values.length - quantity - 1];
                last_value = (value + accumulated_value / int32(quantity)) / 2;
            } else {
                last_value = accumulated_value / int(values.length);
            }
        }
    }

    function reset() public is_owner {
        delete last_value;
        delete values;
        delete accumulated_value;
        delete last_timestamp;
    }
}

