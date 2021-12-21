// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import {IValueProvider} from "./valueprovider/IValueProvider.sol";

contract Oracle {
    IValueProvider public immutable valueProvider;

    uint256 public immutable minTimeBetweenUpdates;

    uint256 public immutable becomeStaleTimeBetweenUpdates;

    uint256 public lastTimestamp;

    // alpha determines how much influence
    // the new value has on the computed moving average
    // A commonly used value is 2 / (N + 1)
    int256 public immutable alpha;

    // current and next EMA computed values
    int256 private _currentValue;
    int256 private _nextValue;

    constructor(
        address valueProvider_,
        uint256 minTimeBetweenUpdates_,
        uint256 becomeStaleTimeBetweenUpdates_,
        int256 alpha_
    ) {
        valueProvider = IValueProvider(valueProvider_);
        minTimeBetweenUpdates = minTimeBetweenUpdates_;
        becomeStaleTimeBetweenUpdates = becomeStaleTimeBetweenUpdates_;
        alpha = alpha_;
    }

    /// @notice Get the current value of the oracle
    /// @return the current value of the oracle
    /// @return whether the value is valid
    function value() public view returns (int256, bool) {
        // Value is considered valid if it was updated before becomeStaleTimeBetweenUpdates ago
        bool valid = block.timestamp <
            lastTimestamp + becomeStaleTimeBetweenUpdates;
        return (_currentValue, valid);
    }

    function update() public returns (int256, bool) {
        // Not enough time has passed since the last update
        if (lastTimestamp + minTimeBetweenUpdates > block.timestamp) {
            return value();
        }

        // Update the value using an exponential moving average
        if (_currentValue == 0) {
            // First update takes the current value
            _nextValue = valueProvider.value();
            _currentValue = _nextValue;
        } else {
            //first update the current value with the current computed EMA
            _currentValue = _nextValue;

            //start the next value window with the current oracle value
            int256 currentAverage = _nextValue;
            int256 newValue = valueProvider.value();
            // EMA = EMA(prev) + alpha * (Value - EMA(prev))
            // Scales down because of fixed number of decimals
            _nextValue =
                currentAverage +
                (alpha * (newValue - currentAverage)) /
                10**18;
        }

        // Save when the value was last updated
        lastTimestamp = block.timestamp;

        // Return value and whether it is valid
        return value();
    }
}
