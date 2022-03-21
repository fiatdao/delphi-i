// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import {Guarded} from "../guarded/Guarded.sol";
import {Pausable} from "../pausable/Pausable.sol";

import {IOracle} from "../oracle/IOracle.sol";
import {IAggregatorOracle} from "./IAggregatorOracle.sol";

contract AggregatorOracle is Guarded, Pausable, IAggregatorOracle, IOracle {
    // @notice Emitted when trying to add an oracle that already exists
    error AggregatorOracle__addOracle_oracleAlreadyRegistered(address oracle);

    // @notice Emitted when trying to remove an oracle that does not exist
    error AggregatorOracle__removeOracle_oracleNotRegistered(address oracle);

    // @notice Emitted when trying to remove an oracle makes a valid value impossible
    error AggregatorOracle__removeOracle_minimumRequiredValidValues_higherThan_oracleCount(
        uint256 requiredValidValues,
        uint256 oracleCount
    );

    // @notice Emitted when one does not have the right permissions to manage _oracles
    error AggregatorOracle__notAuthorized();

    // @notice Emitted when trying to set the minimum number of valid values higher than the oracle count
    error AggregatorOracle__setParam_requiredValidValues_higherThan_oracleCount(
        uint256 requiredValidValues,
        uint256 oracleCount
    );

    // @notice Emitted when trying to set a parameter that does not exist
    error AggregatorOracle__setParam_unrecognizedParam(bytes32 param);

    // @notice Emitted when trying to add a Oracle to the Aggregator but the Aggregator is not whitelisted in the Oracle
    // The Aggregator needs to be able to call Update on all Oracles
    error AggregatorOracle__unauthorizedToCallUpdateOracle(address oracle);
    /// ======== Events ======== ///

    event OracleAdded(address oracleAddress);
    event OracleRemoved(address oracleAddress);
    event OracleUpdated(address oracleAddress);
    event OracleUpdateFailed(address oracleAddress);
    event OracleValue(address oracleAddress, int256 value, bool valid);
    event OracleValueFailed(address oracleAddress);
    event AggregatedValue(int256 value, uint256 validValues);
    event SetParam(bytes32 param, uint256 value);

    /// ======== Storage ======== ///

    // List of registered oracles
    using EnumerableSet for EnumerableSet.AddressSet;
    EnumerableSet.AddressSet private _oracles;

    // Current aggregated value
    int256 private _aggregatedValue;

    // Minimum number of valid values required
    // from oracles to consider an aggregated value valid
    uint256 public requiredValidValues;

    // Number of valid values from oracles
    uint256 private _aggregatedValidValues;

    /// @notice Returns the number of oracles
    function oracleCount()
        public
        view
        override(IAggregatorOracle)
        returns (uint256)
    {
        return _oracles.length();
    }

    /// @notice Returns `true` if the oracle is registered
    function oracleExists(address oracle_)
        public
        view
        override(IAggregatorOracle)
        returns (bool)
    {
        return _oracles.contains(oracle_);
    }

    /// @notice Returns the address of an oracle at index
    /// @param index_ The internal index of the oracle
    /// @return Returns the address pf the oracle
    function oracleAt(uint256 index_)
        external
        view
        override(IAggregatorOracle)
        returns (address)
    {
        return _oracles.at(index_);
    }

    /// @notice Adds an oracle to the list of oracles
    /// @dev Reverts if the oracle is already registered
    function oracleAdd(address oracle_)
        public
        override(IAggregatorOracle)
        checkCaller
    {
        if (!Guarded(oracle_).canCall(IOracle.update.selector, address(this))) {
            revert AggregatorOracle__unauthorizedToCallUpdateOracle(oracle_);
        }

        bool added = _oracles.add(oracle_);
        if (added == false) {
            revert AggregatorOracle__addOracle_oracleAlreadyRegistered(oracle_);
        }

        emit OracleAdded(oracle_);
    }

    /// @notice Removes an oracle from the list of oracles
    /// @dev Reverts if removing the oracle would break the minimum required valid values
    /// @dev Reverts if removing the oracle is not registered
    function oracleRemove(address oracle_)
        public
        override(IAggregatorOracle)
        checkCaller
    {
        uint256 localOracleCount = oracleCount();

        // Make sure the minimum number of required valid values is not higher than the oracle count
        if (requiredValidValues >= localOracleCount) {
            revert AggregatorOracle__removeOracle_minimumRequiredValidValues_higherThan_oracleCount(
                requiredValidValues,
                localOracleCount
            );
        }

        // Try to remove
        bool removed = _oracles.remove(oracle_);
        if (removed == false) {
            revert AggregatorOracle__removeOracle_oracleNotRegistered(oracle_);
        }

        emit OracleRemoved(oracle_);
    }

    /// @notice Update values from oracles and return aggregated value
    function update() public override(IOracle) checkCaller returns (bool) {
        // Call all oracles to update and get values
        uint256 oracleLength = _oracles.length();
        int256[] memory values = new int256[](oracleLength);

        // Count how many oracles have a valid value
        uint256 validValues = 0;

        // Save a flag if at least one oracle updated successfully
        bool updated = false;

        // Update each oracle and get its value
        for (uint256 i = 0; i < oracleLength; i++) {
            IOracle oracle = IOracle(_oracles.at(i));

            try oracle.update() returns (bool localUpdated) {
                // If at least one oracle updated successfully, set the flag
                if (localUpdated) {
                    emit OracleUpdated(address(oracle));
                    updated = true;
                }

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
                    emit OracleValue(address(oracle), returnedValue, isValid);
                } catch {
                    emit OracleValueFailed(address(oracle));
                    continue;
                }
            } catch {
                emit OracleUpdateFailed(address(oracle));
                continue;
            }
        }

        // Aggregate the returned values
        _aggregatedValue = _aggregateValues(values, validValues);

        // Update the number of valid values
        _aggregatedValidValues = validValues;

        emit AggregatedValue(_aggregatedValue, validValues);

        return updated;
    }

    /// @notice Returns the aggregated value
    /// @dev The value is considered valid if
    ///      - the number of valid values is higher than the minimum required valid values
    ///      - the number of required valid values is > 0
    function value()
        public
        view
        override(IOracle)
        whenNotPaused
        returns (int256, bool)
    {
        bool isValid = _aggregatedValidValues >= requiredValidValues &&
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

    function setParam(bytes32 param_, uint256 value_)
        public
        override(IAggregatorOracle)
        checkCaller
    {
        if (param_ == "requiredValidValues") {
            uint256 localOracleCount = oracleCount();
            // Should not be able to set the minimum number of required valid values higher than the oracle count
            if (value_ > localOracleCount) {
                revert AggregatorOracle__setParam_requiredValidValues_higherThan_oracleCount(
                    value_,
                    localOracleCount
                );
            }
            requiredValidValues = value_;
        } else revert AggregatorOracle__setParam_unrecognizedParam(param_);

        emit SetParam(param_, value_);
    }

    /// @notice Aggregates the values
    function _aggregateValues(int256[] memory values_, uint256 validValues_)
        internal
        pure
        returns (int256)
    {
        // Avoid division by zero
        if (validValues_ == 0) {
            return 0;
        }

        int256 sum;
        for (uint256 i = 0; i < validValues_; i++) {
            sum += values_[i];
        }

        return sum / int256(validValues_);
    }
}
