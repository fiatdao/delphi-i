// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import {ElementFiValueProvider} from "src/oracle_implementations/discount_rate/ElementFi/ElementFiValueProvider.sol";

interface IElementFiValueProviderFactory {
    function create(
        // Oracle parameters
        uint256 timeUpdateWindow_,
        //
        bytes32 poolId_,
        address balancerVaultAddress_,
        address poolToken_,
        address underlier_,
        address ePTokenBond_,
        int256 timeScale_,
        uint256 maturity_
    ) external returns (address);
}

contract ElementFiValueProviderFactory is IElementFiValueProviderFactory {
    function create(
        // Oracle parameters
        uint256 timeUpdateWindow_,
        //
        bytes32 poolId_,
        address balancerVaultAddress_,
        address poolToken_,
        address underlier_,
        address ePTokenBond_,
        int256 timeScale_,
        uint256 maturity_
    ) external override(IElementFiValueProviderFactory) returns (address) {
        ElementFiValueProvider elementFiValueProvider = new ElementFiValueProvider(
                timeUpdateWindow_,
                poolId_,
                balancerVaultAddress_,
                poolToken_,
                underlier_,
                ePTokenBond_,
                timeScale_,
                maturity_
            );

        elementFiValueProvider.allowCaller(
            elementFiValueProvider.ANY_SIG(),
            msg.sender
        );
        elementFiValueProvider.blockCaller(
            elementFiValueProvider.ANY_SIG(),
            address(this)
        );

        return address(elementFiValueProvider);
    }
}
