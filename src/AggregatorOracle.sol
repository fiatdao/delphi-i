// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import {Guarded} from "./Guarded.sol";

import {Oracle} from "./Oracle.sol";

// @notice Emitted when trying to add an oracle that already exists
error AggregatorOracle__addOracle_oracleAlreadyRegistered(address oracle);

// @notice Emitted when trying to remove an oracle that does not exist
error AggregatorOracle__removeOracle_oracleNotRegistered(address oracle);

// @notice Emitted when one does not have the right permissions to manage _oracles
error AggregatorOracle__notAuthorized();

contract AggregatorOracle is Guarded {
    using EnumerableSet for EnumerableSet.AddressSet;

    // List of registered oracles
    EnumerableSet.AddressSet private _oracles;

    // Current aggregated value
    int256 private _aggregatedValue;

    /// @notice Returns the number of oracles
    function oracleCount() public view returns (uint256) {
        return _oracles.length();
    }

    /// @notice Adds an oracle to the list of oracles
    function oracleAdd(address oracle) public onlyRoot {
        bool added = _oracles.add(oracle);
        if (added == false) {
            revert AggregatorOracle__addOracle_oracleAlreadyRegistered(oracle);
        }

        // Get the oracle value
        (int256 newValue, ) = Oracle(oracle).update();

        // Update the aggregated value
        _aggregatedValue = _aggregateOracleAdded(newValue);
    }

    /// @notice Returns `true` if the oracle is registered
    function oracleExists(address oracle) public view returns (bool) {
        return _oracles.contains(oracle);
    }

    /// @notice Removes an oracle from the list of oracles
    function oracleRemove(address oracle) public onlyRoot {
        bool removed = _oracles.remove(oracle);
        if (removed == false) {
            revert AggregatorOracle__removeOracle_oracleNotRegistered(oracle);
        }

        // TODO: consider finding an optimized way
        // to update the value without iterating over all oracles
        updateAll();
    }

    /// @notice Update values from oracles and return aggregated value
    function updateAll() public returns (int256, bool) {
        // Call all oracles to update and get values
        uint256 oracleLength = _oracles.length();
        int256[] memory values = new int256[](oracleLength);
        bool[] memory valid = new bool[](oracleLength);
        for (uint256 i = 0; i < oracleLength; i++) {
            (values[i], valid[i]) = Oracle(_oracles.at(i)).update();
        }

        // Aggregate the returned values
        _aggregatedValue = _aggregateValues(values);

        // Return aggregated value
        return value();
    }

    /// @notice Returns the aggregated value
    function value() public view returns (int256, bool) {
        return (_aggregatedValue, true);
    }

    /// @notice Aggregates the values
    function _aggregateValues(int256[] memory values)
        internal
        pure
        returns (int256)
    {
        // Avoid division by zero
        if (values.length == 0) {
            return 0;
        }

        int256 sum;
        for (uint256 i = 0; i < values.length; i++) {
            sum += values[i];
        }

        return sum / int256(values.length);
    }

    function _aggregateOracleAdded(int256 newValue)
        internal
        view
        returns (int256)
    {
        // Get oracle count
        uint256 oracleLength = _oracles.length();

        // If this is the first oracle, return this value
        if (oracleLength == 1) {
            return newValue;
        }

        // Otherwise, return the average of the previous aggregated value and this value
        return
            (_aggregatedValue * (int256(oracleLength) - 1) + newValue) /
            int256(oracleLength);
    }
}
