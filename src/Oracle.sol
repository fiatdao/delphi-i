// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import {IValueProvider} from "./valueprovider/IValueProvider.sol";

contract Oracle {
    IValueProvider public immutable valueProvider;

    uint256 public immutable minTimeBetweenUpdates;

    uint256 public lastTimestamp;

    // alpha determines how much influence the new value has on the old one
    // A commonly used value is 2 / (N + 1)
    uint256 public immutable alpha;

    // Exponential moving average
    uint256 public ema;

    constructor(
        address valueProvider_,
        uint256 minTimeBetweenUpdates_,
        uint256 alpha_
    ) {
        valueProvider = IValueProvider(valueProvider_);
        minTimeBetweenUpdates = minTimeBetweenUpdates_;
        alpha = alpha_;
    }

    function value() public view returns (uint256) {
        return ema;
    }

    function update() public {
        // Not enough time has passed since the last update
        if (lastTimestamp + minTimeBetweenUpdates > block.timestamp) {
            return;
        }

        // Update the value using an exponential moving average
        if (ema == 0) {
            // First update takes the current value
            ema = valueProvider.value();
        } else {
            // EMA = EMA(prev) + alpha * (Value - EMA(prev))
            // Scales down because of fixed number of decimals
            uint256 emaPrevious = ema;
            uint256 currentValue = valueProvider.value();
            ema = emaPrevious + (alpha * (currentValue - emaPrevious)) / 10**18;
        }

        // Save when the value was last updated
        lastTimestamp = block.timestamp;
    }
}
