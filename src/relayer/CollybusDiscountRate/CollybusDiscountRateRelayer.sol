// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import {IRelayer} from "src/relayer/IRelayer.sol";
import {IOracle} from "src/oracle/IOracle.sol";
import {ICollybus} from "src/relayer/ICollybus.sol";
import {Guarded} from "src/guarded/Guarded.sol";

// @notice Emitted when trying to add an oracle that already exists
error CollybusDiscountRateRelayer__addOracle_oracleAlreadyRegistered(
    address oracle
);

// @notice Emitted when trying to add an oracle for a tokenId that already has a registered oracle.
error CollybusDiscountRateRelayer__addOracle_tokenIdHasOracleRegistered(
    address oracle,
    uint256 tokenId
);

// @notice Emitter when trying to remove an oracle that was not registered.
error CollybusDiscountRateRelayer__removeOracle_oracleNotRegistered(
    address oracle
);

contract CollybusDiscountRateRelayer is Guarded, IRelayer {
    struct OracleData {
        bool exists;
        uint256 tokenId;
        int256 lastUpdateValue;
        uint256 minimumThresholdValue;
    }

    /// ======== Events ======== ///

    event OracleAdded(address oracleAddress);
    event OracleRemoved(address oracleAddress);
    event ShouldUpdate(bool shouldUpdate);
    event UpdateOracle(address oracle, int256 value, bool valid);
    event UpdatedCollybus(uint256 tokenId, uint256 rate);

    /// ======== Storage ======== ///

    ICollybus private _collybus;

    // Mapping that will hold all the oracle params needed by the contract
    mapping(address => OracleData) private _oracles;

    // Mapping used tokenId's
    mapping(uint256 => bool) public _tokenIds;

    // Array used for iterating the oracles.
    address[] private _oracleList;

    constructor(address collybusAddress_) {
        _collybus = ICollybus(collybusAddress_);
    }

    /// @notice Returns the number of registered oracles.
    /// @return the total number of oracles.
    function oracleCount() public view returns (uint256) {
        return _oracleList.length;
    }

    /// @notice                         Registers an oracle to a token id and set the minimum threshold delta value
    ///                                 calculate the annual rate.
    /// @param oracle_                  The address of the oracle.
    /// @param tokenId_                 The unique token id for which this oracle will update rate values.
    /// @param minimumThresholdValue_   The minimum value delta threshold needed in order to push values to the Collybus
    /// @dev                            Reverts if the oracle is already registered or if the rate id is taken by another oracle.
    function oracleAdd(
        address oracle_,
        uint256 tokenId_,
        uint256 minimumThresholdValue_
    ) public checkCaller {
        // Make sure the oracle was not added previously
        if (oracleExists(oracle_)) {
            revert CollybusDiscountRateRelayer__addOracle_oracleAlreadyRegistered(
                oracle_
            );
        }

        // Make sure there are no existing oracles registered for this rate Id
        if (_tokenIds[tokenId_]) {
            revert CollybusDiscountRateRelayer__addOracle_tokenIdHasOracleRegistered(
                oracle_,
                tokenId_
            );
        }

        // Add oracle in the oracle address array that is used for iterating.
        _oracleList.push(oracle_);

        // Mark the token Id as used
        _tokenIds[tokenId_] = true;

        // Update the oracle address => data mapping with the oracle parameters.
        _oracles[oracle_] = OracleData({
            exists: true,
            lastUpdateValue: 0,
            tokenId: tokenId_,
            minimumThresholdValue: minimumThresholdValue_
        });

        emit OracleAdded(oracle_);
    }

    /// @notice         Unregisters an oracle.
    /// @param oracle_  The address of the oracle.
    /// @dev            Reverts if the oracle is not registered
    function oracleRemove(address oracle_) public checkCaller {
        // Make sure the oracle is registered
        if (!oracleExists(oracle_)) {
            revert CollybusDiscountRateRelayer__removeOracle_oracleNotRegistered(
                oracle_
            );
        }

        // Reset the tokenId Mapping
        _tokenIds[_oracles[oracle_].tokenId] = false;

        // Remove the oracle index from the array by swapping the target with the last element
        // We only need to iterate length - 1 elements.
        uint256 arrayLength = _oracleList.length;
        for (uint256 i = 0; i < arrayLength - 1; i++) {
            if (_oracleList[i] == oracle_) {
                _oracleList[i] = _oracleList[arrayLength - 1];
                // No need to continue iterating, we found our oracle.
                break;
            }
        }

        // Delete the last element
        _oracleList.pop();

        // Reset struct to default values
        delete _oracles[oracle_];

        emit OracleRemoved(oracle_);
    }

    /// @notice         Checks whether an oracle is registered.
    /// @param oracle_  The address of the oracle.
    /// @return         Returns 'true' if the oracle is registered.
    function oracleExists(address oracle_)
        public
        view
        checkCaller
        returns (bool)
    {
        return _oracles[oracle_].exists;
    }

    /// @notice Iterates and updates each oracle until it finds one that should push data
    ///         in the Collybus, more exactly, the delta change in value is bigger than the minimum
    ///         threshold value set for that oracle.
    /// @dev    Oracles that return invalid values are skipped.
    /// @return Returns 'true' if at least one oracle should update data in the Collybus
    function check() external override(IRelayer) returns (bool) {
        uint256 arrayLength = _oracleList.length;
        for (uint256 i = 0; i < arrayLength; i++) {
            IOracle(_oracleList[i]).update();

            (int256 rate, bool isValid) = IOracle(_oracleList[i]).value();

            emit UpdateOracle(_oracleList[i], rate, isValid);
            if (!isValid) continue;

            if (
                absDelta(_oracles[_oracleList[i]].lastUpdateValue, rate) >=
                _oracles[_oracleList[i]].minimumThresholdValue
            ) {
                emit ShouldUpdate(true);
                return true;
            }
        }

        emit ShouldUpdate(false);
        return false;
    }

    /// @notice Iterates and updates all the oracles and pushes the updated data to Collybus for the
    ///         oracles that have delta changes in value bigger than the minimum threshold values.
    /// @dev    Oracles that return invalid values are skipped.
    function execute() public override(IRelayer) {
        // Update Collybus all tokenIds with the new discount rate
        uint256 arrayLength = _oracleList.length;
        for (uint256 i = 0; i < arrayLength; i++) {
            // We always update the oracles before retrieving the rates
            IOracle(_oracleList[i]).update();
            (int256 rate, bool isValid) = IOracle(_oracleList[i]).value();

            if (!isValid) continue;

            OracleData memory oracleData = _oracles[_oracleList[i]];

            // If the change in delta rate from the last update is bigger than the threshold value push
            // the rates to Collybus
            if (
                absDelta(oracleData.lastUpdateValue, rate) >=
                oracleData.minimumThresholdValue
            ) {
                oracleData.lastUpdateValue = rate;
                _oracles[_oracleList[i]] = oracleData;

                _collybus.updateDiscountRate(oracleData.tokenId, uint256(rate));

                emit UpdatedCollybus(oracleData.tokenId, uint256(rate));
            }
        }
    }

    /// @notice     Computes the positive delta between two signed int256
    /// @param a    First parameter.
    /// @param b    Second parameter.
    /// @return     Returns the positive delta.
    function absDelta(int256 a, int256 b) internal pure returns (uint256) {
        if (a > b) {
            return uint256(a - b);
        }
        return uint256(b - a);
    }
}
