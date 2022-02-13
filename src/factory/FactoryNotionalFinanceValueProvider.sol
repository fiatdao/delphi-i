// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import {NotionalFinanceValueProvider} from "src/oracle_implementations/discount_rate/NotionalFinance/NotionalFinanceValueProvider.sol";

interface IFactoryNotionalFinanceValueProvider {
    function create(
        // Oracle parameters
        uint256 timeUpdateWindow_,
        uint256 maxValidTime_,
        int256 alpha_,
        //
        address notionalViewContract_,
        uint16 currencyId_,
        uint256 lastImpliedRateDecimals_,
        uint256 maturity_,
        uint256 settlementDate_
    ) external returns (address);
}

contract FactoryNotionalFinanceValueProvider is
    IFactoryNotionalFinanceValueProvider
{
    function create(
        // Oracle parameters
        uint256 timeUpdateWindow_,
        uint256 maxValidTime_,
        int256 alpha_,
        //
        address notionalViewContract_,
        uint16 currencyId_,
        uint256 lastImpliedRateDecimals_,
        uint256 maturity_,
        uint256 settlementDate_
    )
        external
        override(IFactoryNotionalFinanceValueProvider)
        returns (address)
    {
        NotionalFinanceValueProvider notionalFinanceValueProvider = new NotionalFinanceValueProvider(
                timeUpdateWindow_,
                maxValidTime_,
                alpha_,
                notionalViewContract_,
                currencyId_,
                lastImpliedRateDecimals_,
                maturity_,
                settlementDate_
            );

        return address(notionalFinanceValueProvider);
    }
}
