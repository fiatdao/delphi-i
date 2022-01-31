// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import {INotionalView, MarketParameters} from "src/oracle_implementations/discount_rate/NotionalFinance/INotionalView.sol";
import {Oracle} from "src/oracle/Oracle.sol";

contract NotionalFinanceValueProvider is Oracle {
    int256 internal constant RATE_PRECISION_CONVERSION = 1e9;

    INotionalView private immutable _notionalView;
    uint16 private immutable _currencyID;
    uint256 private immutable _maturityDate;
    uint256 private immutable _settlementDate;

    /// @notice                         Constructs the Value provider contracts with the needed Notional contract data in order to
    ///                                 calculate the annual rate.
    /// @param notionalViewContract_    The address of the deployed notional view contract.
    /// @param currencyID_              Currency ID(eth = 1, dai = 2, usdc = 3, wbtc = 4)
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
        uint256 maturity_,
        uint256 settlementDate_
    ) Oracle(timeUpdateWindow_, maxValidTime_, alpha_) {
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
        return int256(marketParams.lastImpliedRate) * RATE_PRECISION_CONVERSION;
    }
}
