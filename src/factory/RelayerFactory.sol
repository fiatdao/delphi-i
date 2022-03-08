// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import {Relayer} from "src/relayer/Relayer.sol";
import {IRelayer} from "src/relayer/IRelayer.sol";

interface IRelayerFactory {
    function create(address collybus_, IRelayer.RelayerType relayerType_)
        external
        returns (address);
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
}
