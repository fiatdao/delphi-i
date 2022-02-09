// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import {YieldValueProvider} from "src/oracle_implementations/discount_rate/Yield/YieldValueProvider.sol";

interface IFactoryYieldValueProvider {
    function create(
        // Oracle parameters
        uint256 timeUpdateWindow_,
        uint256 maxValidTime_,
        int256 alpha_,
        //
        address poolAddress_,
        uint256 maturity_,
        int256 timeScale_
    ) external returns (address);
}

contract FactoryYieldValueProvider is IFactoryYieldValueProvider {
    function create(
        // Oracle parameters
        uint256 timeUpdateWindow_,
        uint256 maxValidTime_,
        int256 alpha_,
        //
        address poolAddress_,
        uint256 maturity_,
        int256 timeScale_
    ) public override(IFactoryYieldValueProvider) returns (address) {
        YieldValueProvider yieldValueProvider = new YieldValueProvider(
            timeUpdateWindow_,
            maxValidTime_,
            alpha_,
            poolAddress_,
            maturity_,
            timeScale_
        );

        return address(yieldValueProvider);
    }
}