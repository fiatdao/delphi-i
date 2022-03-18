// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import {IOracle} from "./IOracle.sol";

import {Pausable} from "../pausable/Pausable.sol";

abstract contract Oracle is Pausable, IOracle {
    /// @notice Emitted when a method is reentered
    error Oracle__nonReentrant();

    /// ======== Events ======== ///

    event ValueInvalid();
    event ValueUpdated(int256 currentValue, int256 nextValue);
    event OracleReset();

    /// ======== Storage ======== ///

    uint256 public immutable timeUpdateWindow;

    uint256 public lastTimestamp;
    // next EMA value
    int256 public nextValue;

    // current EMA value and its validity
    int256 private _currentValue;
    bool private _validReturnedValue;

    // reentrancy guard flag
    uint256 private _reentrantGuard = 1;

    /// ======== Modifiers ======== ///

    modifier nonReentrant() {
        // Check if the guard is set
        if (_reentrantGuard != 1) {
            revert Oracle__nonReentrant();
        }

        // Set the guard
        _reentrantGuard = 2;

        // Allow execution
        _;

        // Reset the guard
        _reentrantGuard = 1;
    }

    constructor(uint256 timeUpdateWindow_) {
        timeUpdateWindow = timeUpdateWindow_;
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
        // Value is considered valid if the value provider successfully returned a value
        return (_currentValue, _validReturnedValue);
    }

    function getValue() external virtual returns (int256);

    function update()
        public
        override(IOracle)
        checkCaller
        nonReentrant
        returns (bool)
    {
        // Not enough time has passed since the last update
        if (lastTimestamp + timeUpdateWindow > block.timestamp) {
            // Exit early if no update is needed
            return false;
        }

        // Oracle update should not fail even if the value provider fails to return a value
        try this.getValue() returns (int256 returnedValue) {
            // Update the value using an exponential moving average
            if (_currentValue == 0) {
                // First update takes the current value
                nextValue = returnedValue;
                _currentValue = nextValue;
            } else {
                // Update the current value with the next value
                _currentValue = nextValue;
                // Set the returnedValue as the next value
                nextValue = returnedValue;
            }

            // Save when the value was last updated
            lastTimestamp = block.timestamp;
            _validReturnedValue = true;

            emit ValueUpdated(_currentValue, nextValue);

            return true;
        } catch {
            // When a value provider fails, we update the valid flag which will
            // invalidate the value instantly
            _validReturnedValue = false;
            emit ValueInvalid();
        }

        return false;
    }

    function pause() public checkCaller {
        _pause();
    }

    function unpause() public checkCaller {
        _unpause();
    }

    function reset() public whenPaused checkCaller {
        _currentValue = 0;
        nextValue = 0;
        lastTimestamp = 0;
        _validReturnedValue = false;

        emit OracleReset();
    }
}
