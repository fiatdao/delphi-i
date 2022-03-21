// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import {NotionalFinanceValueProvider} from "src/oracle_implementations/discount_rate/NotionalFinance/NotionalFinanceValueProvider.sol";

interface INotionalFinanceValueProviderFactory {
    function create(
        // Oracle parameters
        uint256 timeUpdateWindow_,
        //
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
        //
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

        notionalFinanceValueProvider.allowCaller(
            notionalFinanceValueProvider.ANY_SIG(),
            msg.sender
        );
        return address(notionalFinanceValueProvider);
    }
}
