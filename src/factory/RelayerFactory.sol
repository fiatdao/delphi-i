// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;
import {Relayer} from "../relayer/Relayer.sol";
import {StaticRelayer} from "../relayer/StaticRelayer.sol";
import {IRelayer} from "../relayer/IRelayer.sol";
import {IRelayerFactory} from "./IRelayerFactory.sol";

contract RelayerFactory is IRelayerFactory {
    // Emitted when a Relayer is created
    event RelayerDeployed(
        address relayerAddress,
        IRelayer.RelayerType relayerType,
        address oracleAddress,
        bytes32 encodedTokenId,
        uint256 minimumPercentageDeltaValue
    );
    // Emitted when a Static Relayer is created
    event StaticRelayerDeployed(
        address relayerAddress,
        IRelayer.RelayerType relayerType,
        bytes32 encodedTokenId,
        uint256 value
    );

    /// @notice Creates a Relayer contract that manages an Oracle in order to push data to Collybus
    /// @param collybus_ The address of the Collybus where the Relayer will push data
    /// @param relayerType_ Relayer type, can be DiscountRate or SpotPrice
    /// @param oracleAddress_ The address of the oracle that will provide data
    /// @param encodedTokenId_ Encoded tokenId that will be used to push data to Collybus
    /// @param minimumPercentageDeltaValue_ Minimum delta value used to decide when to push data to Collybus
    function create(
        address collybus_,
        Relayer.RelayerType relayerType_,
        address oracleAddress_,
        bytes32 encodedTokenId_,
        uint256 minimumPercentageDeltaValue_
    ) public override(IRelayerFactory) returns (address) {
        Relayer relayer = new Relayer(
            collybus_,
            relayerType_,
            oracleAddress_,
            encodedTokenId_,
            minimumPercentageDeltaValue_
        );

        // Pass permissions to the intended contract owner
        relayer.allowCaller(relayer.ANY_SIG(), msg.sender);
        relayer.blockCaller(relayer.ANY_SIG(), address(this));

        emit RelayerDeployed(
            address(relayer),
            relayerType_,
            oracleAddress_,
            encodedTokenId_,
            minimumPercentageDeltaValue_
        );
        return address(relayer);
    }

    /// @notice Creates a Static Relayer contract that acts as a one time data provider.
    /// @param collybus_ The address of the Collybus where the StaticRelayer will push data
    /// @param relayerType_ Relayer type, can be DiscountRate or SpotPrice
    /// @param encodedTokenId_ Encoded tokenId that will be used to push data to Collybus
    /// @param value_ The value that will be pushed.
    /// @dev The contract will self-destruct after the rate is successfully pushed to Collybus
    function createStatic(
        address collybus_,
        Relayer.RelayerType relayerType_,
        bytes32 encodedTokenId_,
        uint256 value_
    ) public override(IRelayerFactory) returns (address) {
        // Create the Static Relayer contract
        StaticRelayer staticRelayer = new StaticRelayer(
            collybus_,
            relayerType_,
            encodedTokenId_,
            value_
        );

        // Pass permissions to the intended contract owner
        staticRelayer.allowCaller(staticRelayer.ANY_SIG(), msg.sender);
        staticRelayer.blockCaller(staticRelayer.ANY_SIG(), address(this));

        emit StaticRelayerDeployed(
            address(staticRelayer),
            relayerType_,
            encodedTokenId_,
            value_
        );
        return address(staticRelayer);
    }
}
