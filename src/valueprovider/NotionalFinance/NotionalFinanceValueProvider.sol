// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import {IValueProvider} from "src/valueprovider/IValueProvider.sol";
import {INotionalView, MarketParameters} from "src/valueprovider/NotionalFinance/INotionalView.sol";

import {Convert} from "src/valueprovider/utils/Convert.sol";
import "lib/prb-math/contracts/PRBMathSD59x18.sol";

// @notice Emitted when trying to add pull a value for an expired pool
error NotionalFinanceValueProvider__value_maturityLessThanBlocktime(
    uint256 maturity
);

contract NotionalFinanceValueProvider is IValueProvider, Convert {
    // Seconds in a 360 days year as used by Notional
    int256 internal constant SECONDS_PER_YEAR = 31104000 * 1e18;

    address public immutable notionalView;
    uint16 public immutable currencyID;
    uint256 public immutable maturityDate;
    uint256 public immutable settlementDate;

    uint256 private immutable lastImpliedRateDecimals;

    /// @notice                         Constructs the Value provider contracts with the needed Notional contract data in order to
    ///                                 calculate the annual rate.
    /// @param notionalViewContract_    The address of the deployed notional view contract.
    /// @param currencyID_              Currency ID(eth = 1, dai = 2, usdc = 3, wbtc = 4)
    /// @param lastImpliedRateDecimals_ Precision of the market rate.
    /// @param maturity_                Maturity date.
    /// @param settlementDate_          Settlement date.
    constructor(
        address notionalViewContract_,
        uint16 currencyID_,
        uint256 lastImpliedRateDecimals_,
        uint256 maturity_,
        uint256 settlementDate_
    ) {
        lastImpliedRateDecimals = lastImpliedRateDecimals_;
        notionalView = notionalViewContract_;
        currencyID = currencyID_;
        maturityDate = maturity_;
        settlementDate = settlementDate_;
    }

    /// @notice Calculates the annual rate used by the FIAT DAO contracts
    /// the rate is precomputed by the notional contract and scaled to 1e18 precision.
    /// @dev For more details regarding the computed rate in the Notional contracts:
    /// https://github.com/notional-finance/contracts-v2/blob/b8e3792e39486b2719c6153acc270199377cc6b9/contracts/internal/markets/Market.sol#L495
    /// @return result The result as an signed 59.18-decimal fixed-point number.
    function value() external view override(IValueProvider) returns (int256) {
        // No values for matured pools
        if (block.timestamp >= maturityDate) {
            revert NotionalFinanceValueProvider__value_maturityLessThanBlocktime(
                maturityDate
            );
        }

        // The returned annual rate is in 1e9 precision so we need to convert it to 1e18 precision.
        MarketParameters memory marketParams = INotionalView(notionalView)
            .getMarket(currencyID, maturityDate, settlementDate);

        // Convert rate per anum to 18 digits precision.
        uint256 ratePerAnnum = uconvert(
            marketParams.lastImpliedRate,
            lastImpliedRateDecimals,
            18
        );

        // Convert per anum to per second rate
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
