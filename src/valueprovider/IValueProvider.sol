// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

interface IValueProvider {
    function value() external returns (int256);
}
