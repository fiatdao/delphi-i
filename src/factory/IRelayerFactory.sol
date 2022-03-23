// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

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
