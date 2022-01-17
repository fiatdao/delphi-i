// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

interface IRelayer {
    function check() external returns (bool);

    function execute() external;
}
