// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import {Guarded} from "src/guarded/Guarded.sol";
import {Pausable} from "src/pausable/Pausable.sol";

import {Oracle} from "src/oracle/Oracle.sol";
import {IOracle} from "src/oracle/IOracle.sol";

// @notice Emitted when trying to add an oracle that already exists
error AggregatorOracle__addOracle_oracleAlreadyRegistered(address oracle);

// @notice Emitted when trying to remove an oracle that does not exist
error AggregatorOracle__removeOracle_oracleNotRegistered(address oracle);

// @notice Emitted when trying to remove an oracle makes a valid value impossible
error AggregatorOracle__removeOracle_minimumRequiredValidValues_higherThan_oracleCount(
    uint256 minimumRequiredValidValues,
    uint256 oracleCount
);

// @notice Emitted when one does not have the right permissions to manage _oracles
error AggregatorOracle__notAuthorized();

// @notice Emitted when trying to set the minimum number of valid values higher than the oracle count
error AggregatorOracle__setMinimumRequiredValidValues_higherThan_oracleCount(
    uint256 minimumRequiredValidValues,
    uint256 oracleCount
);

contract AggregatorOracle is Guarded, Pausable, IOracle {
    using EnumerableSet for EnumerableSet.AddressSet;

    // List of registered oracles
    EnumerableSet.AddressSet private _oracles;

    // Current aggregated value
    int256 private _aggregatedValue;

    // Minimum number of valid values required
    // from oracles to consider an aggregated value valid
    uint256 public minimumRequiredValidValues;

    // Number of valid values from oracles
    uint256 private _aggregatedValidValues;

    /// @notice Returns the number of oracles
    function oracleCount() public view returns (uint256) {
        return _oracles.length();
    }

    /// @notice Adds an oracle to the list of oracles
    function oracleAdd(address oracle) public checkCaller {
        bool added = _oracles.add(oracle);
        if (added == false) {
            revert AggregatorOracle__addOracle_oracleAlreadyRegistered(oracle);
        }
    }

    /// @notice Returns `true` if the oracle is registered
    function oracleExists(address oracle) public view returns (bool) {
        return _oracles.contains(oracle);
    }

    /// @notice Removes an oracle from the list of oracles
    function oracleRemove(address oracle) public checkCaller {
        uint256 localOracleCount = oracleCount();

        // Make sure the minimum number of required valid values is not higher than the oracle count
        if (minimumRequiredValidValues >= localOracleCount) {
            revert AggregatorOracle__removeOracle_minimumRequiredValidValues_higherThan_oracleCount(
                minimumRequiredValidValues,
                localOracleCount
            );
        }

        // Try to remove
        bool removed = _oracles.remove(oracle);
        if (removed == false) {
            revert AggregatorOracle__removeOracle_oracleNotRegistered(oracle);
        }
    }

    /// @notice Update values from oracles and return aggregated value
    function update() public override(IOracle) {
        // Call all oracles to update and get values
        uint256 oracleLength = _oracles.length();
        int256[] memory values = new int256[](oracleLength);

        // Count how many oracles have a valid value
        uint256 validValues = 0;

        // Update each oracle and get its value
        for (uint256 i = 0; i < oracleLength; i++) {
            Oracle oracle = Oracle(_oracles.at(i));

            try oracle.update() {
                try oracle.value() returns (
                    int256 returnedValue,
                    bool isValid
                ) {
                    if (isValid) {
                        // Add the value to the list of valid values
                        values[validValues] = returnedValue;

                        // Increase count of valid values
                        validValues++;
                    }
                } catch {}
            } catch {}
        }

        // Aggregate the returned values
        _aggregatedValue = _aggregateValues(values, validValues);

        // Update the number of valid values
        _aggregatedValidValues = validValues;
    }

    /// @notice Returns the aggregated value
    function value()
        public
        view
        override(IOracle)
        whenNotPaused
        returns (int256, bool)
    {
        bool isValid = _aggregatedValidValues >= minimumRequiredValidValues &&
            _aggregatedValidValues > 0;
        return (_aggregatedValue, isValid);
    }

    /// @notice Pause contract
    function pause() public checkCaller {
        _pause();
    }

    /// @notice Unpause contract
    function unpause() public checkCaller {
        _unpause();
    }

    function setMinimumRequiredValidValues(uint256 minimumRequiredValidValues_)
        public
        checkCaller
    {
        uint256 localOracleCount = oracleCount();
        if (minimumRequiredValidValues_ > localOracleCount) {
            revert AggregatorOracle__setMinimumRequiredValidValues_higherThan_oracleCount(
                minimumRequiredValidValues_,
                localOracleCount
            );
        }
        minimumRequiredValidValues = minimumRequiredValidValues_;
    }

    /// @notice Aggregates the values
    function _aggregateValues(int256[] memory values, uint256 validValues)
        internal
        pure
        returns (int256)
    {
        // Avoid division by zero
        if (validValues == 0) {
            return 0;
        }

        int256 sum;
        for (uint256 i = 0; i < validValues; i++) {
            sum += values[i];
        }

        return sum / int256(validValues);
    }
}
