// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import {Relayer} from "../relayer/Relayer.sol";
import {StaticRelayer} from "../relayer/StaticRelayer.sol";
import {IRelayer} from "../relayer/IRelayer.sol";

interface IRelayerFactory {
    function create(
        address collybus_,
        IRelayer.RelayerType relayerType_,
        address oracleAddress,
        bytes32 encodedTokenId,
        uint256 minimumPercentageDeltaValue
    ) external returns (address);

    function createStatic(
        address collybus_,
        IRelayer.RelayerType relayerType_,
        bytes32 encodedTokenId_,
        uint256 value_
    ) external returns (address);
}

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
