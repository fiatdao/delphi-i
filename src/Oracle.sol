// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import {IValueProvider} from "./valueprovider/IValueProvider.sol";

contract Oracle {
    IValueProvider public immutable valueProvider;

    uint256 public immutable windowLength;
    uint256 public immutable minTimeBetweenUpdates;

    uint256 public lastTimestamp;
    uint256 public lastBlock;

    constructor(
        address valueProvider_,
        uint256 windowLength_,
        uint256 minTimeBetweenUpdates_
    ) {
        valueProvider = IValueProvider(valueProvider_);
        windowLength = windowLength_;
        minTimeBetweenUpdates = minTimeBetweenUpdates_;
    }

    function getValue() public returns (uint256) {
        return valueProvider.getValue();
    }

    function update() public {
        if (lastTimestamp + minTimeBetweenUpdates > block.timestamp) {
            return;
        }
        lastBlock = block.number;
        lastTimestamp = block.timestamp;
    }
}
