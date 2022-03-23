// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import {YieldValueProvider} from "src/oracle_implementations/discount_rate/Yield/YieldValueProvider.sol";

interface IYieldValueProviderFactory {
    function create(
        // Oracle parameters
        uint256 timeUpdateWindow_,
        //
        address poolAddress_,
        uint256 maturity_,
        int256 timeScale_
    ) external returns (address);
}

contract YieldValueProviderFactory is IYieldValueProviderFactory {
    function create(
        // Oracle parameters
        uint256 timeUpdateWindow_,
        //
        address poolAddress_,
        uint256 maturity_,
        int256 timeScale_
    ) public override(IYieldValueProviderFactory) returns (address) {
        YieldValueProvider yieldValueProvider = new YieldValueProvider(
            timeUpdateWindow_,
            poolAddress_,
            maturity_,
            timeScale_
        );

        yieldValueProvider.allowCaller(
            yieldValueProvider.ANY_SIG(),
            msg.sender
        );
        yieldValueProvider.blockCaller(
            yieldValueProvider.ANY_SIG(),
            address(this)
        );
        return address(yieldValueProvider);
    }
}
