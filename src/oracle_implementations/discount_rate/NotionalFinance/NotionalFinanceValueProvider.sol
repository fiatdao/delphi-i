// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import {Convert} from "../utils/Convert.sol";
import {INotionalView, MarketParameters} from "./INotionalView.sol";
import {Oracle} from "../../../oracle/Oracle.sol";
import "prb-math/contracts/PRBMathSD59x18.sol";

contract NotionalFinanceValueProvider is Oracle, Convert {
    // @notice Emitted when trying to add pull a value for an expired pool
    error NotionalFinanceValueProvider__value_maturityLessThanBlocktime(
        uint256 maturity
    );

    // Seconds in a 360 days year as used by Notional in 18 digits precision
    int256 internal constant SECONDS_PER_YEAR = 31104000 * 1e18;

    address public immutable notionalView;
    uint256 public immutable currencyId;
    uint256 public immutable maturityDate;
    uint256 public immutable settlementDate;

    uint256 private immutable lastImpliedRateDecimals;

    /// @notice Constructs the Value provider contracts with the needed Notional contract data in order to
    /// calculate the annual rate.
    /// @param timeUpdateWindow_ Minimum time between updates of the value
    /// @param notionalViewContract_ The address of the deployed notional view contract.
    /// @param currencyId_ Currency ID(eth = 1, dai = 2, usdc = 3, wbtc = 4)
    /// @param lastImpliedRateDecimals_ Precision of the Notional Market rate.
    /// @param maturity_ Maturity date.
    /// @param settlementDate_ Settlement date.
    constructor(
        // Oracle parameters
        uint256 timeUpdateWindow_,
        // Notional specific parameters
        address notionalViewContract_,
        uint256 currencyId_,
        uint256 lastImpliedRateDecimals_,
        uint256 maturity_,
        uint256 settlementDate_
    ) Oracle(timeUpdateWindow_) {
        lastImpliedRateDecimals = lastImpliedRateDecimals_;
        notionalView = notionalViewContract_;
        currencyId = currencyId_;
        maturityDate = maturity_;
        settlementDate = settlementDate_;
    }

    /// @notice Calculates the annual rate used by the FIAT DAO contracts
    /// the rate is precomputed by the notional contract and scaled to 1e18 precision
    /// @dev For more details regarding the computed rate in the Notional contracts:
    /// https://github.com/notional-finance/contracts-v2/blob/b8e3792e39486b2719c6153acc270199377cc6b9/contracts/internal/markets/Market.sol#L495
    /// @return result The result as an signed 59.18-decimal fixed-point number
    function getValue() external view override(Oracle) returns (int256) {
        // No values for matured pools
        if (block.timestamp >= maturityDate) {
            revert NotionalFinanceValueProvider__value_maturityLessThanBlocktime(
                maturityDate
            );
        }

        // The returned annual rate is in 1e9 precision so we need to convert it to 1e18 precision.
        MarketParameters memory marketParams = INotionalView(notionalView)
            .getMarket(uint16(currencyId), maturityDate, settlementDate);

        // Convert rate per annum to 18 digits precision.
        uint256 ratePerAnnum = uconvert(
            marketParams.oracleRate,
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
