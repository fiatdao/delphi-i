// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import {Convert} from "../utils/Convert.sol";
import {INotionalView, MarketParameters} from "./INotionalView.sol";
import {Oracle} from "../../../oracle/Oracle.sol";
import "prb-math/contracts/PRBMathSD59x18.sol";

contract NotionalFinanceValueProvider is Oracle, Convert {
    // @notice Emitted when trying to add pull a value for an expired pool
    error NotionalFinanceValueProvider__getValue_maturityLessThanBlocktime(
        uint256 maturity
    );

    // @notice Emitted when an invalid currencyId is used to deploy the contract
    error NotionalFinanceValueProvider__constructor_invalidCurrencyId(
        uint256 currencyId
    );

    // @notice Emitted when no active market is found for a currencyId
    error NotionalFinanceValueProvider__getValue_noActiveMarketFound(
        uint256 currencyId
    );

    // @notice Emitted when the parameters do not map to an active / initialized Notional Market
    error NotionalFinanceValueProvider__getValue_invalidMarketParameters(
        uint256 currencyId,
        uint256 maturityDate
    );

    // Seconds in a 360 days year as used by Notional in 18 digits precision
    int256 internal constant SECONDS_PER_YEAR = 31104000 * 1e18;

    address public immutable notionalView;
    uint256 public immutable currencyId;
    uint256 public immutable maturityDate;

    uint256 private immutable lastImpliedRateDecimals;

    /// @notice Constructs the Value provider contracts with the needed Notional contract data in order to
    /// calculate the annual rate.
    /// @param timeUpdateWindow_ Minimum time between updates of the value
    /// @param notionalViewContract_ The address of the deployed notional view contract.
    /// @param currencyId_ Currency ID(eth = 1, dai = 2, usdc = 3, wbtc = 4)
    /// @param lastImpliedRateDecimals_ Precision of the Notional Market rate.
    /// @param maturity_ Maturity date.
    /// @dev reverts if the CurrencyId is bigger than uint16 max value
    constructor(
        // Oracle parameters
        uint256 timeUpdateWindow_,
        // Notional specific parameters
        address notionalViewContract_,
        uint256 currencyId_,
        uint256 lastImpliedRateDecimals_,
        uint256 maturity_
    ) Oracle(timeUpdateWindow_) {
        if (currencyId_ > type(uint16).max) {
            revert NotionalFinanceValueProvider__constructor_invalidCurrencyId(
                currencyId_
            );
        }

        lastImpliedRateDecimals = lastImpliedRateDecimals_;
        notionalView = notionalViewContract_;
        currencyId = currencyId_;
        maturityDate = maturity_;
    }

    /// @notice Calculates the annual rate used by the FIAT DAO contracts
    /// the rate is precomputed by the notional contract and scaled to 1e18 precision
    /// @dev For more details regarding the computed rate in the Notional contracts:
    /// https://github.com/notional-finance/contracts-v2/blob/b8e3792e39486b2719c6153acc270199377cc6b9/contracts/internal/markets/Market.sol#L495
    /// @return result The result as an signed 59.18-decimal fixed-point number
    function getValue() external view override(Oracle) returns (int256) {
        // No values for matured pools
        if (block.timestamp >= maturityDate) {
            revert NotionalFinanceValueProvider__getValue_maturityLessThanBlocktime(
                maturityDate
            );
        }

        // Get all active markets for the set currencyId
        MarketParameters[] memory activeMarkets = INotionalView(notionalView)
            .getActiveMarkets(uint16(currencyId));

        // If no active markets are found for the currencyId we need to revert
        if (activeMarkets.length == 0) {
            revert NotionalFinanceValueProvider__getValue_noActiveMarketFound(
                currencyId
            );
        }

        uint256 oracleRate = 0;
        // We need to iterate though all the active markets and match via the maturityDate
        for (uint256 idx = 0; idx < activeMarkets.length; ++idx) {
            if (activeMarkets[idx].maturity == maturityDate) {
                oracleRate = activeMarkets[idx].oracleRate;
                break;
            }
        }

        // If the oracleRate is not set it means there are no markets for our currencyId and maturityData
        if (oracleRate <= 0) {
            revert NotionalFinanceValueProvider__getValue_invalidMarketParameters(
                currencyId,
                maturityDate
            );
        }

        // Convert rate per annum to 18 digits precision.
        uint256 ratePerAnnum = uconvert(
            oracleRate,
            lastImpliedRateDecimals,
            18
        );

        // Convert per annum to per second rate
        int256 ratePerSecondD59x18 = PRBMathSD59x18.div(
            int256(ratePerAnnum),
            SECONDS_PER_YEAR
        );

        // Convert continuous compounding to discrete compounding rate
        int256 discreteRateD59x18 = PRBMathSD59x18.exp(ratePerSecondD59x18) -
            PRBMathSD59x18.SCALE;

        // The result is a 59.18 fixed-point number.
        return discreteRateD59x18;
    }
}
