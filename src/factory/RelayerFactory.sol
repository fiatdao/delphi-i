// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import {Relayer} from "src/relayer/Relayer.sol";
import {StaticRelayer} from "src/relayer/StaticRelayer.sol";
import {IRelayer} from "src/relayer/IRelayer.sol";

interface IRelayerFactory {
    function create(address collybus_, IRelayer.RelayerType relayerType_)
        external
        returns (address);

    function createStatic(
        address collybus_,
        IRelayer.RelayerType relayerType_,
        bytes32 encodedTokenId_,
        uint256 value_
    ) external returns (address);
}

contract RelayerFactory is IRelayerFactory {
    function create(address collybus_, Relayer.RelayerType relayerType_)
        public
        override(IRelayerFactory)
        returns (address)
    {
        Relayer relayer = new Relayer(collybus_, relayerType_);
        relayer.allowCaller(relayer.ANY_SIG(), msg.sender);
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
        return address(staticRelayer);
    }
}
