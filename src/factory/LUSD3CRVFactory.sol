// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import {LUSD3CRVValueProvider} from "../oracle_implementations/spot_price/Chainlink/LUSD3CRV/LUSD3CRVValueProvider.sol";
import {Relayer} from "../relayer/Relayer.sol";
import {IRelayer} from "../relayer/IRelayer.sol";

contract LUSD3CRVFactory {
    event LUSD3CRVDeployed(address relayerAddress, address oracleAddress);

    /// @param collybus_ Address of the collybus
    /// @param tokenAddress_ Token address that will be used to push values to Collybus
    /// @param minimumPercentageDeltaValue_ Minimum delta value used to determine when to
    /// push data to Collybus
    /// @param timeUpdateWindow_ Minimum time between updates of the value
    /// @param curve3Pool_ Address of the  Curve 3pool
    /// @param curve3PoolLpToken_ Address of the lp token for the Curve 3pool
    /// @param chainlinkLUSD_ Address of the LUSD chainlink data feed
    /// @param chainlinkUSDC_ Address of the USDC chainlink data feed
    /// @param chainlinkDAI_ Address of the DAI chainlink data feed
    /// @param chainlinkUSDT_ Address of the USDT chainlink data feed
    function create(
        // Relayer parameters
        address collybus_,
        address tokenAddress_,
        uint256 minimumPercentageDeltaValue_,
        // Oracle parameters
        uint256 timeUpdateWindow_,
        // LUSD3CRVValueProvider specific parameters
        address curve3Pool_,
        address curve3PoolLpToken_,
        address chainlinkLUSD_,
        address chainlinkUSDC_,
        address chainlinkDAI_,
        address chainlinkUSDT_
    ) public returns (address) {
        // The tokenAddress is the address of the LUSD3CRV Curve Pool so we can pass it to the Oracle
        LUSD3CRVValueProvider lusd3crvValueProvider = new LUSD3CRVValueProvider(
            timeUpdateWindow_,
            curve3Pool_,
            curve3PoolLpToken_,
            tokenAddress_,
            chainlinkLUSD_,
            chainlinkUSDC_,
            chainlinkDAI_,
            chainlinkUSDT_
        );

        // Create the relayer that manages the oracle and pushes data to Collybus
        Relayer relayer = new Relayer(
            collybus_,
            IRelayer.RelayerType.SpotPrice,
            address(lusd3crvValueProvider),
            bytes32(uint256(uint160(tokenAddress_))),
            minimumPercentageDeltaValue_
        );

        // Whitelist the Relayer in the Oracle so it can trigger updates
        lusd3crvValueProvider.allowCaller(
            lusd3crvValueProvider.ANY_SIG(),
            address(relayer)
        );

        // Whitelist the deployer
        lusd3crvValueProvider.allowCaller(
            lusd3crvValueProvider.ANY_SIG(),
            msg.sender
        );
        relayer.allowCaller(relayer.ANY_SIG(), msg.sender);

        // Renounce permissions
        lusd3crvValueProvider.blockCaller(
            lusd3crvValueProvider.ANY_SIG(),
            address(this)
        );
        relayer.blockCaller(relayer.ANY_SIG(), address(this));

        emit LUSD3CRVDeployed(address(relayer), address(lusd3crvValueProvider));

        return address(relayer);
    }
}
