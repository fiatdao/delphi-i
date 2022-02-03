// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import {ChainLinkValueProvider} from "src/oracle_implementations/spot_price/Chainlink/ChainLinkValueProvider.sol";

interface IFactoryChainLinkValueProvider{
    function create(
        // Oracle parameters
        uint256 timeUpdateWindow_,
        uint256 maxValidTime_,
        int256 alpha_,
        //
        address chainlinkAggregatorAddress_
    ) external returns(address);
}

contract FactoryChainLinkValueProvider is IFactoryChainLinkValueProvider{
    function create(
        // Oracle parameters
        uint256 timeUpdateWindow_,
        uint256 maxValidTime_,
        int256 alpha_,
        //
        address chainlinkAggregatorAddress_
    ) public override(IFactoryChainLinkValueProvider) returns(address){

        ChainLinkValueProvider chainlinkValueProvider = new ChainLinkValueProvider(
            timeUpdateWindow_,
            maxValidTime_,
            alpha_,
            chainlinkAggregatorAddress_
        );

        return address(chainlinkValueProvider);
    }
}