// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import {IValueProvider} from "./valueprovider/IValueProvider.sol";

import {IOracle} from "./IOracle.sol";

import {Pausable} from "./Pausable.sol";

contract Oracle is Pausable, IOracle {
    IValueProvider public immutable valueProvider;

    uint256 public immutable timeUpdateWindow;

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

    bool private _validReturnedValue;

    // RESET_ROLE is able to reset the oracle
    bytes32 public constant RESET_ROLE = keccak256("RESET_ROLE");

    constructor(
        address valueProvider_,
        uint256 timeUpdateWindow_,
        uint256 maxValidTime_,
        int256 alpha_
    ) {
        valueProvider = IValueProvider(valueProvider_);
        timeUpdateWindow = timeUpdateWindow_;
        maxValidTime = maxValidTime_;
        alpha = alpha_;
        _validReturnedValue = false;
    }

    /// @notice Get the current value of the oracle
    /// @return the current value of the oracle
    /// @return whether the value is valid
    function value()
        public
        view
        override(IOracle)
        whenNotPaused
        returns (int256, bool)
    {
        // Value is considered valid if the value provider succesfully returned a value
        // and it was updated before maxValidTime ago
        bool valid = _validReturnedValue &&
            (block.timestamp < lastTimestamp + maxValidTime);
        return (_currentValue, valid);
    }

    function update() public override(IOracle) {
        // Not enough time has passed since the last update
        if (lastTimestamp + timeUpdateWindow > block.timestamp) {
            // Exit early if no update is needed
            return;
        }

        // Oracle update should not fail even if the value provider fails to return a value
        try valueProvider.value() returns (int256 returnedValue) {
            // Update the value using an exponential moving average
            if (_currentValue == 0) {
                // First update takes the current value
                nextValue = returnedValue;
                _currentValue = nextValue;
            } else {
                // Update the current value with the next value
                _currentValue = nextValue;

                // Update the EMA and store it in the next value
                int256 newValue = returnedValue;
                // EMA = EMA(prev) + alpha * (Value - EMA(prev))
                // Scales down because of fixed number of decimals
                nextValue =
                    _currentValue +
                    (alpha * (newValue - _currentValue)) /
                    10**18;
            }

            // Save when the value was last updated
            lastTimestamp = block.timestamp;
            _validReturnedValue = true;
        } catch {
            // When a value provider fails, we update the valid flag which will
            // invalidate the value instantly
            _validReturnedValue = false;
        }
    }

    function reset() public whenPaused onlyRole(RESET_ROLE) {
        _currentValue = 0;
        nextValue = 0;
        lastTimestamp = 0;
        _validReturnedValue = false;
    }
}
