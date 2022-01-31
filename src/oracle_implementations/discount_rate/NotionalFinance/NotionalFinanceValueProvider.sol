// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import {Convert} from "src/oracle_implementations/discount_rate/utils/Convert.sol";
import {INotionalView, MarketParameters} from "src/oracle_implementations/discount_rate/NotionalFinance/INotionalView.sol";
import {Oracle} from "src/oracle/Oracle.sol";
import "lib/prb-math/contracts/PRBMathSD59x18.sol";

contract NotionalFinanceValueProvider is Oracle, Convert {
    // Seconds in a 360 days year as used by Notional
    int256 internal constant SECONDS_PER_YEAR = 31104000 * 1e18;

    INotionalView private immutable _notionalView;
    uint16 private immutable _currencyID;
    uint256 private immutable _maturityDate;
    uint256 private immutable _settlementDate;

    uint256 private immutable _lastImpliedRateDecimals;

    /// @notice                         Constructs the Value provider contracts with the needed Notional contract data in order to
    ///                                 calculate the annual rate.
    /// @param timeUpdateWindow_        Minimum time between updates of the value
    /// @param maxValidTime_            Maximum time for which the value is valid
    /// @param alpha_                   Alpha parameter for EMA
    /// @param notionalViewContract_    The address of the deployed notional view contract.
    /// @param currencyID_              Currency ID(eth = 1, dai = 2, usdc = 3, wbtc = 4)
    /// @param lastImpliedRateDecimals_ Precision of the market rate.
    /// @param maturity_                Maturity date.
    /// @param settlementDate_          Settlement date.
    constructor(
        // Oracle parameters
        uint256 timeUpdateWindow_,
        uint256 maxValidTime_,
        int256 alpha_,
        //
        address notionalViewContract_,
        uint16 currencyID_,
        uint256 lastImpliedRateDecimals_,
        uint256 maturity_,
        uint256 settlementDate_
    ) Oracle(timeUpdateWindow_, maxValidTime_, alpha_) {
        _lastImpliedRateDecimals = lastImpliedRateDecimals_;
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
    function getValue() external view override(Oracle) returns (int256) {
        // The returned annual rate is in 1e9 precision so we need to convert it to 1e18 precision.
        MarketParameters memory marketParams = _notionalView.getMarket(
            _currencyID,
            _maturityDate,
            _settlementDate
        );

        // Convert rate per anum to 18 digits precision.
        uint256 ratePerAnnum = uconvert(
            marketParams.lastImpliedRate,
            _lastImpliedRateDecimals,
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
