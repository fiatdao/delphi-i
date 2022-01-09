// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import {IValueProvider} from "../IValueProvider.sol";

contract NotionalFinanceValueProvider is IValueProvider {
    constructor()
    {

    }

    function value() external view override(IValueProvider) returns (int256) {
        return 0;
    }
}