// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

interface IOracle {
    function value() external view returns (int256, bool);

    function update() external;
}
