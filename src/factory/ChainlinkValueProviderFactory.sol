// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import {ChainLinkValueProvider} from "../oracle_implementations/spot_price/Chainlink/ChainLinkValueProvider.sol";

interface IChainlinkValueProviderFactory {
    function create(
        // Oracle parameters
        uint256 timeUpdateWindow_,
        // Chainlink specific parameters, see ChainLinkValueProvider for more info
        address chainlinkAggregatorAddress_
    ) external returns (address);
}

contract ChainlinkValueProviderFactory is IChainlinkValueProviderFactory {
    event ChainlinkValueProviderDeployed(address oracleAddress);

    function create(
        // Oracle parameters
        uint256 timeUpdateWindow_,
        // Chainlink specific parameters, see ChainLinkValueProvider for more info
        address chainlinkAggregatorAddress_
    ) public override(IChainlinkValueProviderFactory) returns (address) {
        ChainLinkValueProvider chainlinkValueProvider = new ChainLinkValueProvider(
                timeUpdateWindow_,
                chainlinkAggregatorAddress_
            );

        // Transfer permissions to the intended owner
        chainlinkValueProvider.allowCaller(
            chainlinkValueProvider.ANY_SIG(),
            msg.sender
        );

        chainlinkValueProvider.blockCaller(
            chainlinkValueProvider.ANY_SIG(),
            address(this)
        );

        emit ChainlinkValueProviderDeployed(address(chainlinkValueProvider));
        return address(chainlinkValueProvider);
    }
}
