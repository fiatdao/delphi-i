// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import {ChainLinkValueProvider} from "../oracle_implementations/spot_price/Chainlink/ChainLinkValueProvider.sol";
import {Relayer} from "../relayer/Relayer.sol";
import {IRelayer} from "../relayer/IRelayer.sol";

contract ChainlinkFactory {
    event ChainlinkDeployed(address relayerAddress, address oracleAddress);

    /// @param collybus_ Address of the collybus
    /// @param tokenAddress_ Token address that will be used to push values to Collybus
    /// @param minimumPercentageDeltaValue_ Minimum delta value used to determine when to
    /// push data to Collybus
    /// @param chainlinkAggregatorAddress_ Address of the deployed chainlink aggregator contract.
    /// @return The address of the Relayer
    function create(
        // Relayer parameters
        address collybus_,
        address tokenAddress_,
        uint256 minimumPercentageDeltaValue_,
        // Oracle parameters
        uint256 timeUpdateWindow_,
        // Chainlink specific parameters, see ChainLinkValueProvider for more info
        address chainlinkAggregatorAddress_
    ) public returns (address) {
        ChainLinkValueProvider chainlinkValueProvider = new ChainLinkValueProvider(
                timeUpdateWindow_,
                chainlinkAggregatorAddress_
            );

        // Create the relayer that manages the oracle and pushes data to Collybus
        Relayer relayer = new Relayer(
            collybus_,
            IRelayer.RelayerType.SpotPrice,
            address(chainlinkValueProvider),
            bytes32(uint256(uint160(tokenAddress_))),
            minimumPercentageDeltaValue_
        );

        // Whitelist the Relayer in the Oracle so it can trigger updates
        chainlinkValueProvider.allowCaller(
            chainlinkValueProvider.ANY_SIG(),
            address(relayer)
        );

        // Whitelist the deployer
        chainlinkValueProvider.allowCaller(
            chainlinkValueProvider.ANY_SIG(),
            msg.sender
        );
        relayer.allowCaller(relayer.ANY_SIG(), msg.sender);

        // Renounce permissions
        chainlinkValueProvider.blockCaller(
            chainlinkValueProvider.ANY_SIG(),
            address(this)
        );
        relayer.blockCaller(relayer.ANY_SIG(), address(this));

        emit ChainlinkDeployed(
            address(relayer),
            address(chainlinkValueProvider)
        );
        return address(relayer);
    }
}
