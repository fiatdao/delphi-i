// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import {IValueProvider} from "./valueprovider/IValueProvider.sol";

contract Oracle {
    IValueProvider public immutable valueProvider;

    uint256 public immutable minTimeBetweenUpdates;

    uint256 public immutable maxValidTime;

    uint256 public lastTimestamp;

    // alpha determines how much influence
    // the new value has on the computed moving average
    // A commonly used value is 2 / (N + 1)
    int256 public immutable alpha;

    // next EMA value
    int256 public nextValue;

    // current EMA value
    int256 private _currentValue;

    constructor(
        address valueProvider_,
        uint256 minTimeBetweenUpdates_,
        uint256 maxValidTime_,
        int256 alpha_
    ) {
        valueProvider = IValueProvider(valueProvider_);
        minTimeBetweenUpdates = minTimeBetweenUpdates_;
        maxValidTime = maxValidTime_;
        alpha = alpha_;
    }

    /// @notice Get the current value of the oracle
    /// @return the current value of the oracle
    /// @return whether the value is valid
    function value() public view returns (int256, bool) {
        // Value is considered valid if it was updated before becomeStaleTimeBetweenUpdates ago
        bool valid = block.timestamp <
            lastTimestamp + maxValidTime;
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
            nextValue = valueProvider.value();
            _currentValue = nextValue;
        } else {
            // Update the current value with the next value
            _currentValue = nextValue;

            // Update the EMA and store it in the next value
            int256 newValue = valueProvider.value();
            // EMA = EMA(prev) + alpha * (Value - EMA(prev))
            // Scales down because of fixed number of decimals
            nextValue =
                _currentValue +
                (alpha * (newValue - _currentValue)) /
                10**18;
        }

        // Save when the value was last updated
        lastTimestamp = block.timestamp;

        // Return value and whether it is valid
        return value();
    }
}
