// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

interface IValueProvider {
    function getValue() external returns (uint256);
}
