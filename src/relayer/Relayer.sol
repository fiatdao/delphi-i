// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import {IRelayer} from "./IRelayer.sol";
import {IOracle} from "../oracle/IOracle.sol";
import {ICollybus} from "./ICollybus.sol";
import {Guarded} from "../guarded/Guarded.sol";

contract Relayer is Guarded, IRelayer {
    // @notice Emitter when execute() does not update any oracle
    error Relayer__executeWithRevert_noUpdates(RelayerType relayerType);

    // @notice Emitted when trying to set a parameter that does not exist
    error Relayer__setParam_unrecognizedParam(bytes32 param);

    event SetParam(bytes32 param, uint256 value);
    event UpdateOracle(address oracle, int256 value, bool valid);
    event UpdatedCollybus(bytes32 tokenId, uint256 rate, RelayerType);

    /// ======== Storage ======== ///

    address public immutable collybus;
    RelayerType public immutable relayerType;
    address public immutable oracle;
    bytes32 public immutable encodedTokenId;

    uint256 public minimumPercentageDeltaValue;
    int256 private _lastUpdateValue;

    /// @param collybusAddress_ Address of the collybus
    /// @param type_ Relayer type, DiscountRate or SpotPrice
    /// @param encodedTokenId_ Encoded token Id that will be used to push values to Collybus
    /// uint256 for discount rate, address for spot price
    /// @param minimumPercentageDeltaValue_ Minimum delta value used to determine when to
    /// push data to Collybus
    constructor(
        address collybusAddress_,
        RelayerType type_,
        address oracleAddress_,
        bytes32 encodedTokenId_,
        uint256 minimumPercentageDeltaValue_
    ) {
        collybus = collybusAddress_;
        relayerType = type_;
        oracle = oracleAddress_;
        encodedTokenId = encodedTokenId_;
        minimumPercentageDeltaValue = minimumPercentageDeltaValue_;
        _lastUpdateValue = 0;
    }

    /// @notice Sets a Relayer parameter
    /// Supported parameters are:
    /// - minimumPercentageDeltaValue
    /// @param param_ The identifier of the parameter that should be updated
    /// @param value_ The new value
    /// @dev Reverts if parameter is not found
    function setParam(bytes32 param_, uint256 value_) public checkCaller {
        if (param_ == "minimumPercentageDeltaValue") {
            minimumPercentageDeltaValue = value_;
        } else revert Relayer__setParam_unrecognizedParam(param_);

        emit SetParam(param_, value_);
    }

    /// @notice Iterates and updates all the oracles and pushes the updated data to Collybus for the
    /// oracles that have delta changes in value bigger than the minimum threshold values.
    /// @dev Oracles that return invalid values are skipped.
    function execute() public override(IRelayer) checkCaller returns (bool) {
        // We always update the oracles before retrieving the rates
        bool oracleUpdated = IOracle(oracle).update();
        (int256 oracleValue, bool isValid) = IOracle(oracle).value();

        // If the oracle was not updated or the value was invalid then we can exit early as we will not push data to Collybus
        if (!oracleUpdated || !isValid) {
            return oracleUpdated;
        }

        // If the change in delta rate from the last update is bigger than the threshold value push
        // the rates to Collybus
        if (
            checkDeviation(
                _lastUpdateValue,
                oracleValue,
                minimumPercentageDeltaValue
            )
        ) {
            _lastUpdateValue = oracleValue;

            if (relayerType == RelayerType.DiscountRate) {
                ICollybus(collybus).updateDiscountRate(
                    uint256(encodedTokenId),
                    uint256(oracleValue)
                );
            } else if (relayerType == RelayerType.SpotPrice) {
                ICollybus(collybus).updateSpot(
                    address(uint160(uint256(encodedTokenId))),
                    uint256(oracleValue)
                );
            }

            emit UpdatedCollybus(
                encodedTokenId,
                uint256(oracleValue),
                relayerType
            );
        }

        return oracleUpdated;
    }

    /// @notice The function will call `execute()` and will revert if no oracle was updated
    /// @dev This method is needed for services that try to updates the oracles on each block and only call the method if it doesn't fail
    function executeWithRevert() public override(IRelayer) {
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
