// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {IRelayer} from "./IRelayer.sol";
import {IOracle} from "../oracle/IOracle.sol";
import {ICollybus} from "./ICollybus.sol";
import {Guarded} from "../guarded/Guarded.sol";

contract Relayer is Guarded, IRelayer {
    // @notice Emitted when trying to add an oracle that already exists
    error Relayer__addOracle_oracleAlreadyRegistered(
        address oracle,
        RelayerType relayerType
    );

    // @notice Emitted when trying to add an oracle for a tokenId that already has a registered oracle.
    error Relayer__addOracle_tokenIdHasOracleRegistered(
        address oracle,
        bytes32 tokenId,
        RelayerType relayerType
    );

    // @notice Emitter when trying to remove an oracle that was not registered.
    error Relayer__removeOracle_oracleNotRegistered(
        address oracle,
        RelayerType relayerType
    );

    // @notice Emitter when execute() does not update any oracle
    error Relayer__executeWithRevert_noUpdates(RelayerType relayerType);

    // @notice Emitted when trying to add a Oracle to the Relayer but the Relayer is not whitelisted in the Oracle
    //         The Relayer needs to be able to call Update on all Oracles
    error Relayer__unauthorizedToCallUpdateOracle(address oracleAddress);

    struct OracleData {
        bool exists;
        bytes32 tokenId;
        int256 lastUpdateValue;
        uint256 minimumPercentageDeltaValue;
    }

    /// ======== Events ======== ///

    event OracleAdded(address oracleAddress);
    event OracleRemoved(address oracleAddress);
    event ShouldUpdate(bool shouldUpdate);
    event UpdateOracle(address oracle, int256 value, bool valid);
    event UpdatedCollybus(bytes32 tokenId, uint256 rate, RelayerType);

    /// ======== Storage ======== ///

    address public immutable collybus;

    RelayerType public immutable relayerType;

    // Mapping that will hold all the oracle params needed by the contract
    mapping(address => OracleData) private _oraclesData;

    // Mapping used tokenId's
    mapping(bytes32 => bool) public encodedTokenIds;

    // Array used for iterating the oracles.
    using EnumerableSet for EnumerableSet.AddressSet;
    EnumerableSet.AddressSet private _oracleList;

    constructor(address collybusAddress_, RelayerType type_) {
        collybus = collybusAddress_;
        relayerType = type_;
    }

    /// @notice Returns the number of registered oracles.
    /// @return the total number of oracles.
    function oracleCount() external view override(IRelayer) returns (uint256) {
        return _oracleList.length();
    }

    /// @notice Returns the address of an oracle at index
    /// @dev Reverts if the index is out of bounds
    /// @param index_ The internal index of the oracle
    /// @return Returns the address pf the oracle
    function oracleAt(uint256 index_)
        external
        view
        override(IRelayer)
        returns (address)
    {
        return _oracleList.at(index_);
    }

    /// @notice Checks whether an oracle is registered.
    /// @param oracle_ The address of the oracle.
    /// @return Returns 'true' if the oracle is registered.
    function oracleExists(address oracle_)
        public
        view
        override(IRelayer)
        returns (bool)
    {
        return _oraclesData[oracle_].exists;
    }

    /// @notice Registers an oracle to a token id and set the minimum threshold delta value
    /// calculate the annual rate.
    /// @param oracle_ The address of the oracle.
    /// @param encodedTokenId_ The unique token id for which this oracle will update rate values.
    /// @param minimumPercentageDeltaValue_ The minimum value delta threshold needed in order to push values to the Collybus
    /// @dev Reverts if the oracle is already registered or if the rate id is taken by another oracle.
    function oracleAdd(
        address oracle_,
        bytes32 encodedTokenId_,
        uint256 minimumPercentageDeltaValue_
    ) public override(IRelayer) checkCaller {
        if (!Guarded(oracle_).canCall(IOracle.update.selector, address(this))) {
            revert Relayer__unauthorizedToCallUpdateOracle(oracle_);
        }

        // Make sure the oracle was not added previously
        if (oracleExists(oracle_)) {
            revert Relayer__addOracle_oracleAlreadyRegistered(
                oracle_,
                relayerType
            );
        }

        // Make sure there are no existing oracles registered for this rate Id
        if (encodedTokenIds[encodedTokenId_]) {
            revert Relayer__addOracle_tokenIdHasOracleRegistered(
                oracle_,
                encodedTokenId_,
                relayerType
            );
        }

        // Add oracle in the oracle address array that is used for iterating.
        _oracleList.add(oracle_);

        // Mark the token Id as used
        encodedTokenIds[encodedTokenId_] = true;

        // Update the oracle address => data mapping with the oracle parameters.
        _oraclesData[oracle_] = OracleData({
            exists: true,
            lastUpdateValue: 0,
            tokenId: encodedTokenId_,
            minimumPercentageDeltaValue: minimumPercentageDeltaValue_
        });

        emit OracleAdded(oracle_);
    }

    /// @notice Unregisters an oracle.
    /// @param oracle_ The address of the oracle.
    /// @dev Reverts if the oracle is not registered
    function oracleRemove(address oracle_)
        public
        override(IRelayer)
        checkCaller
    {
        // Make sure the oracle is registered
        if (!oracleExists(oracle_)) {
            revert Relayer__removeOracle_oracleNotRegistered(
                oracle_,
                relayerType
            );
        }

        // Reset the tokenId Mapping
        encodedTokenIds[_oraclesData[oracle_].tokenId] = false;

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

    /// @notice Iterates and updates all the oracles and pushes the updated data to Collybus for the
    /// oracles that have delta changes in value bigger than the minimum threshold values.
    /// @dev Oracles that return invalid values are skipped.
    function execute() public override(IRelayer) checkCaller returns (bool) {
        bool updated;

        // Update Collybus all tokenIds with the new discount rate
        uint256 arrayLength = _oracleList.length();
        for (uint256 i = 0; i < arrayLength; i++) {
            // Cache oracle address
            address localOracle = _oracleList.at(i);

            // We always update the oracles before retrieving the rates
            bool oracleUpdated = IOracle(localOracle).update();
            if (oracleUpdated) {
                updated = true;
            }
            (int256 oracleValue, bool isValid) = IOracle(localOracle).value();

            // If the value is invalid we don't need to update Collybus
            if (!isValid) continue;

            // If the oracle was not updated we don't need to update Collybus
            if (!oracleUpdated) continue;

            OracleData storage oracleData = _oraclesData[localOracle];

            // If the change in delta rate from the last update is bigger than the threshold value push
            // the rates to Collybus
            if (
                checkDeviation(
                    oracleData.lastUpdateValue,
                    oracleValue,
                    oracleData.minimumPercentageDeltaValue
                )
            ) {
                oracleData.lastUpdateValue = oracleValue;

                if (relayerType == RelayerType.DiscountRate) {
                    ICollybus(collybus).updateDiscountRate(
                        uint256(oracleData.tokenId),
                        uint256(oracleValue)
                    );
                } else if (relayerType == RelayerType.SpotPrice) {
                    ICollybus(collybus).updateSpot(
                        address(uint160(uint256(oracleData.tokenId))),
                        uint256(oracleValue)
                    );
                }

                emit UpdatedCollybus(
                    oracleData.tokenId,
                    uint256(oracleValue),
                    relayerType
                );
            }
        }

        return updated;
    }

    /// @notice The function will call `execute()` and will revert if no oracle was updated
    /// @dev This method is needed for services that try to updates the oracles on each block and only call the method if it doesn't fail
    function executeWithRevert() public override(IRelayer) checkCaller {
        if (!execute()) {
            revert Relayer__executeWithRevert_noUpdates(relayerType);
        }
    }

    /// @notice Returns true if the percentage difference between the two values is bigger than the `percentage`
    /// @param baseValue_ The value that the percentage is based on
    /// @param newValue_ The new value
    /// @param percentage_ The percentage threshold value (100% = 100_00, 50% = 50_00, etc)
    function checkDeviation(
        int256 baseValue_,
        int256 newValue_,
        uint256 percentage_
    ) public pure returns (bool) {
        int256 deviation = (baseValue_ * int256(percentage_)) / 100_00;

        if (
            baseValue_ + deviation <= newValue_ ||
            baseValue_ - deviation >= newValue_
        ) return true;

        return false;
    }
}
