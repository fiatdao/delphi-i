// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import {IValueProvider} from "src/valueprovider/IValueProvider.sol";
import {INotionalView, MarketParameters} from "src/valueprovider/NotionalFinance/INotionalView.sol";
import "lib/prb-math/contracts/PRBMathSD59x18.sol";

// @notice Emitted when a token with unsupported decimals is used
error NotionalFinanceValueProvider__unsupportedDecimalFormat(uint16 currencyID);

contract NotionalFinanceValueProvider is IValueProvider {
    //Julien year, 365.25 days
    int256 internal constant SECONDS_PER_YEAR = 31557600;

    INotionalView private immutable _notionalView;
    uint16 private immutable _currencyID;
    uint256 private immutable _maturityDate;
    uint256 private immutable _settlementDate;

    uint256 private immutable _decimalConversion;

    /// @notice                         Constructs the Value provider contracts with the needed Notional contract data in order to
    ///                                 calculate the annual rate.
    /// @param notionalViewContract_    The address of the deployed notional view contract.
    /// @param currencyID_              Currency ID(eth = 1, dai = 2, usdc = 3, wbtc = 4)
    /// @param maturity_                Maturity date.
    /// @param settlementDate_          Settlement date.
    constructor(
        address notionalViewContract_,
        uint16 currencyID_,
        uint256 decimals_,
        uint256 maturity_,
        uint256 settlementDate_
    ) {
        if (decimals_ > 18) {
            revert NotionalFinanceValueProvider__unsupportedDecimalFormat(
                currencyID_
            );
        }

        _decimalConversion = 10**(18 - decimals_);

        _notionalView = INotionalView(notionalViewContract_);
        _currencyID = currencyID_;
        _maturityDate = maturity_;
        _settlementDate = settlementDate_;
    }

    /// @notice Calculates the annual rate used by the FIAT DAO contracts
    /// the rate is precomputed by the notional contract and scaled to 1e18 precision.
    /// @dev For more details regarding the computed rate in the Notional contracts:
    /// https://github.com/notional-finance/contracts-v2/blob/b8e3792e39486b2719c6153acc270199377cc6b9/contracts/internal/markets/Market.sol#L495
    /// @return result The result as an signed 59.18-decimal fixed-point number.
    function value() external view override(IValueProvider) returns (int256) {
        // The returned annual rate is in 1e9 precision so we need to convert it to 1e18 precision.
        MarketParameters memory marketParams = _notionalView.getMarket(
            _currencyID,
            _maturityDate,
            _settlementDate
        );

        // Convert rate per anum to 18 digits precision.
        int256 ratePerAnnum = int256(marketParams.lastImpliedRate) *
            int256(_decimalConversion);

        // Apply rate per second conversion formula
        int256 ratePerSecondD59x18 = PRBMathSD59x18.pow(
            PRBMathSD59x18.SCALE + ratePerAnnum,
            PRBMathSD59x18.div(
                PRBMathSD59x18.SCALE,
                PRBMathSD59x18.fromInt(SECONDS_PER_YEAR)
            )
        ) - PRBMathSD59x18.SCALE;

        // The result is a 59.18 fixed-point number.
        return ratePerSecondD59x18;
    }
}
