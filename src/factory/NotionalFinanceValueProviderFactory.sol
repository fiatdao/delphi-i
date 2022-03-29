// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import {NotionalFinanceValueProvider} from "../oracle_implementations/discount_rate/NotionalFinance/NotionalFinanceValueProvider.sol";

interface INotionalFinanceValueProviderFactory {
    function create(
        // Oracle parameters
        uint256 timeUpdateWindow_,
        // Notional specific parameters, see NotionalFinanceValueProvider for more info
        address notionalViewContract_,
        uint16 currencyId_,
        uint256 lastImpliedRateDecimals_,
        uint256 maturity_,
        uint256 settlementDate_
    ) external returns (address);
}

contract NotionalFinanceValueProviderFactory is
    INotionalFinanceValueProviderFactory
{
    function create(
        // Oracle parameters
        uint256 timeUpdateWindow_,
        // Notional specific parameters, see NotionalFinanceValueProvider for more info
        address notionalViewContract_,
        uint16 currencyId_,
        uint256 lastImpliedRateDecimals_,
        uint256 maturity_,
        uint256 settlementDate_
    )
        external
        override(INotionalFinanceValueProviderFactory)
        returns (address)
    {
        NotionalFinanceValueProvider notionalFinanceValueProvider = new NotionalFinanceValueProvider(
                timeUpdateWindow_,
                notionalViewContract_,
                currencyId_,
                lastImpliedRateDecimals_,
                maturity_,
                settlementDate_
            );

        // Transfer permissions to the intended owner
        notionalFinanceValueProvider.allowCaller(
            notionalFinanceValueProvider.ANY_SIG(),
            msg.sender
        );

        notionalFinanceValueProvider.blockCaller(
            notionalFinanceValueProvider.ANY_SIG(),
            address(this)
        );

        return address(notionalFinanceValueProvider);
    }
}
