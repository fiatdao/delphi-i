// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import {Relayer} from "src/relayer/Relayer.sol";
import {IRelayer} from "src/relayer/IRelayer.sol";

interface IFactoryRelayer {
    function create(address collybus_, IRelayer.RelayerType relayerType_)
        external
        returns (address);
}

contract FactoryRelayer is IFactoryRelayer {
    function create(address collybus_, Relayer.RelayerType relayerType_)
        public
        override(IFactoryRelayer)
        returns (address)
    {
        Relayer relayer = new Relayer(collybus_, relayerType_);
        relayer.allowCaller(relayer.ANY_SIG(), msg.sender);
        return address(relayer);
    }
}
