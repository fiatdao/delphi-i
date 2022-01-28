// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {ICollybusSpotPriceRelayer} from "src/relayer/CollybusSpotPrice/ICollybusSpotPriceRelayer.sol";
import {IRelayer} from "src/relayer/IRelayer.sol";
import {IOracle} from "src/oracle/IOracle.sol";
import {ICollybus} from "src/relayer/ICollybus.sol";
import {Guarded} from "src/guarded/Guarded.sol";

// @notice Emitted when trying to add an oracle that already exists
error CollybusSpotPriceRelayer__addOracle_oracleAlreadyRegistered(
    address oracle
);

// @notice Emitted when trying to add an oracle for a tokenId that already has a registered oracle.
error CollybusSpotPriceRelayer__addOracle_tokenIdHasOracleRegistered(
    address oracle,
    address tokenAddress
);

// @notice Emitter when trying to remove an oracle that was not registered.
error CollybusSpotPriceRelayer__removeOracle_oracleNotRegistered(
    address oracle
);

contract CollybusSpotPriceRelayer is Guarded, ICollybusSpotPriceRelayer {
    struct OracleData {
        bool exists;
        address tokenAddress;
        int256 lastUpdateValue;
        uint256 minimumThresholdValue;
    }

    /// ======== Events ======== ///

    event OracleAdded(address oracleAddress);
    event OracleRemoved(address oracleAddress);
    event ShouldUpdate(bool shouldUpdate);
    event UpdateOracle(address oracle, int256 value, bool valid);
    event UpdatedCollybus(address tokenAddress, uint256 rate);

    /// ======== Storage ======== ///

    address public immutable collybus;

    // Mapping that will hold all the oracle params needed by the contract
    mapping(address => OracleData) private _oraclesData;

    // Mapping used to track used Rate Ids.
    mapping(address => bool) public tokenIds;

    // Array used for iterating the oracles.
    using EnumerableSet for EnumerableSet.AddressSet;
    EnumerableSet.AddressSet private _oracleList;

    constructor(address collybusAddress_) {
        collybus = collybusAddress_;
    }

    /// @notice Returns the number of registered oracles.
    /// @return the total number of oracles.
    function oracleCount()
        public
        view
        override(ICollybusSpotPriceRelayer)
        returns (uint256)
    {
        return _oracleList.length();
    }

    /// @notice         Returns the address of an oracle at index
    /// @dev            Reverts if the index is out of bounds
    /// @param index_   The internal index of the oracle
    /// @return         Returns the address pf the oracle
    function oracleAt(uint256 index_)
        external
        view
        override(ICollybusSpotPriceRelayer)
        returns (address)
    {
        return _oracleList.at(index_);
    }

    /// @notice         Checks whether an oracle is registered
    /// @param oracle_  The address of the oracle
    /// @return         Returns 'true' if the oracle is registered
    function oracleExists(address oracle_)
        public
        view
        override(ICollybusSpotPriceRelayer)
        returns (bool)
    {
        return _oraclesData[oracle_].exists;
    }

    /// @notice                         Registers an oracle to a token id and set the minimum threshold delta value
    ///                                 calculate the annual rate.
    /// @param oracle_                  The address of the oracle.
    /// @param tokenAddress_            The address of the underlier token.
    /// @param minimumThresholdValue_   The minimum value delta threshold needed in order to push values to the Collybus
    /// @dev                            Reverts if the oracle is already registered or if the rate id is taken by another oracle.
    function oracleAdd(
        address oracle_,
        address tokenAddress_,
        uint256 minimumThresholdValue_
    ) public override(ICollybusSpotPriceRelayer) checkCaller {
        // Make sure the oracle was not added previously
        if (oracleExists(oracle_)) {
            revert CollybusSpotPriceRelayer__addOracle_oracleAlreadyRegistered(
                oracle_
            );
        }

        // Make sure there are no existing oracles registered for this rate Id
        if (tokenIds[tokenAddress_]) {
            revert CollybusSpotPriceRelayer__addOracle_tokenIdHasOracleRegistered(
                oracle_,
                tokenAddress_
            );
        }

        // Add oracle in the oracle address array that is used for iterating.
        _oracleList.add(oracle_);

        // Mark the token address as used
        tokenIds[tokenAddress_] = true;

        // Update the oracle address => data mapping with the oracle parameters.
        _oraclesData[oracle_] = OracleData({
            exists: true,
            lastUpdateValue: 0,
            tokenAddress: tokenAddress_,
            minimumThresholdValue: minimumThresholdValue_
        });

        emit OracleAdded(oracle_);
    }

    /// @notice         Unregisters an oracle.
    /// @param oracle_  The address of the oracle.
    /// @dev            Reverts if the oracle is not registered
    function oracleRemove(address oracle_)
        public
        override(ICollybusSpotPriceRelayer)
        checkCaller
    {
        // Make sure the oracle is registered
        if (!oracleExists(oracle_)) {
            revert CollybusSpotPriceRelayer__removeOracle_oracleNotRegistered(
                oracle_
            );
        }

        // Reset the token address Mapping
        tokenIds[_oraclesData[oracle_].tokenAddress] = false;

        // Remove the oracle from the list
        // This returns true/false depending on if the oracle was removed
        _oracleList.remove(oracle_);

        // Reset struct to default values
        delete _oraclesData[oracle_];

        emit OracleRemoved(oracle_);
    }

    /// @notice Returns the oracle data for a given oracle address
    /// @param oracle_ The address of the oracle
    /// @return Returns the oracle data as `OracleData`
    function oraclesData(address oracle_)
        public
        view
        returns (OracleData memory)
    {
        return _oraclesData[oracle_];
    }

    /// @notice Iterates and updates each oracle until it finds one that should push data
    ///         in the Collybus, more exactly, the delta change in value is greater than the minimum
    ///         threshold value set for that oracle.
    /// @dev    Oracles that return invalid values are skipped.
    /// @return Returns 'true' if at least one oracle should update data in the Collybus
    function check() external override(IRelayer) returns (bool) {
        uint256 arrayLength = _oracleList.length();
        for (uint256 i = 0; i < arrayLength; i++) {
            // Cache oracle address
            address localOracle = _oracleList.at(i);

            // Trigger the oracle to update its data
            IOracle(localOracle).update();

            (int256 rate, bool isValid) = IOracle(localOracle).value();

            emit UpdateOracle(localOracle, rate, isValid);
            if (!isValid) continue;

            if (
                absDelta(_oraclesData[localOracle].lastUpdateValue, rate) >=
                _oraclesData[localOracle].minimumThresholdValue
            ) {
                emit ShouldUpdate(true);
                return true;
            }
        }

        emit ShouldUpdate(false);
        return false;
    }

    /// @notice Iterates and updates all the oracles and pushes the updated data to Collybus for the
    ///         oracles that have delta changes in value greater than the minimum threshold values.
    /// @dev    Oracles that return invalid values are skipped.
    function execute() public override(IRelayer) {
        // Update Collybus all tokenIds with the new discount rate
        uint256 arrayLength = _oracleList.length();
        for (uint256 i = 0; i < arrayLength; i++) {
            // Cache oracle address
            address localOracle = _oracleList.at(i);

            // We always update the oracles before retrieving the rates
            IOracle(localOracle).update();
            (int256 rate, bool isValid) = IOracle(localOracle).value();

            if (!isValid) continue;

            OracleData storage oracleData = _oraclesData[localOracle];

            // If the change in delta rate from the last update is greater or equal than the threshold value
            // push the rates to Collybus
            if (
                absDelta(oracleData.lastUpdateValue, rate) >=
                oracleData.minimumThresholdValue
            ) {
                oracleData.lastUpdateValue = rate;
                ICollybus(collybus).updateSpot(oracleData.tokenAddress, uint256(rate));

                emit UpdatedCollybus(oracleData.tokenAddress, uint256(rate));
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
