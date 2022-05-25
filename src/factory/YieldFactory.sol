// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import {YieldValueProvider} from "../oracle_implementations/discount_rate/Yield/YieldValueProvider.sol";
import {Relayer} from "../relayer/Relayer.sol";
import {IRelayer} from "../relayer/IRelayer.sol";

contract YieldFactory {
    event YieldDeployed(address relayerAddress, address oracleAddress);

    /// @param collybus_ Address of the collybus
    /// @param tokenId_ Token id that will be used to push values to Collybus
    /// @param minimumPercentageDeltaValue_ Minimum delta value used to determine when to
    /// push data to Collybus
    /// @param timeUpdateWindow_ Minimum time between updates of the value
    /// @param poolAddress_ Address of the pool
    /// @param maturity_ Expiration of the pool
    /// @param timeScale_ Time scale used on this pool (i.e. 1/(timeStretch*secondsPerYear)) in 59x18 fixed point
    /// @param cumulativeBalanceTimestamp_ The time at which the provided balance ratio was computed
    /// @param cumulativeBalancesRatio_ The current balance ratio that will be used as a starting value
    /// @return The address of the Relayer
    function create(
        // Relayer parameters
        address collybus_,
        uint256 tokenId_,
        uint256 minimumPercentageDeltaValue_,
        // Oracle parameters
        uint256 timeUpdateWindow_,
        // Yield specific parameters, see YieldValueProvider for more info
        address poolAddress_,
        uint256 maturity_,
        int256 timeScale_,
        uint256 cumulativeBalanceTimestamp_,
        uint256 cumulativeBalancesRatio_
    ) public returns (address) {
        YieldValueProvider yieldValueProvider = new YieldValueProvider(
            timeUpdateWindow_,
            poolAddress_,
            maturity_,
            timeScale_,
            cumulativeBalanceTimestamp_,
            cumulativeBalancesRatio_
        );

        // Create the relayer that manages the oracle and pushes data to Collybus
        Relayer relayer = new Relayer(
            collybus_,
            IRelayer.RelayerType.DiscountRate,
            address(yieldValueProvider),
            bytes32(tokenId_),
            minimumPercentageDeltaValue_
        );

        // Whitelist the Relayer in the Oracle so it can trigger updates
        yieldValueProvider.allowCaller(
            yieldValueProvider.ANY_SIG(),
            address(relayer)
        );

        // Whitelist the deployer
        yieldValueProvider.allowCaller(
            yieldValueProvider.ANY_SIG(),
            msg.sender
        );
        relayer.allowCaller(relayer.ANY_SIG(), msg.sender);

        // Renounce permissions
        yieldValueProvider.blockCaller(
            yieldValueProvider.ANY_SIG(),
            address(this)
        );
        relayer.blockCaller(relayer.ANY_SIG(), address(this));

        emit YieldDeployed(address(relayer), address(yieldValueProvider));
        return address(relayer);
    }
}
