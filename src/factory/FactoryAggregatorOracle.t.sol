// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import "ds-test/test.sol";

import {MockProvider} from "@cleanunicorn/mockprovider/src/MockProvider.sol";

import {FactoryAggregatorOracle} from "src/factory/FactoryAggregatorOracle.sol";

import {AggregatorOracle} from "src/aggregator/AggregatorOracle.sol";

contract FactoryAggregatorOracleTest is DSTest {
    FactoryAggregatorOracle private _factory;

    function setUp() public {
        _factory = new FactoryAggregatorOracle();
    }

    function test_deploy() public {
        assertTrue(address(_factory) != address(0));
    }

    function test_create() public {
        address oracleAddress = _factory.create();

        assertTrue(
            oracleAddress != address(0),
            "Factory Aggregator Oracle create failed"
        );
    }

    function test_create_AddsPermission_OnSender() public {
        address oracle = _factory.create();

        assertTrue(
            AggregatorOracle(oracle).canCall(AggregatorOracle(oracle).ANY_SIG(), address(this)),
            "Creator shold have admin access"
        );
    }
}
