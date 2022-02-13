// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import "ds-test/test.sol";

import {MockProvider} from "@cleanunicorn/mockprovider/src/MockProvider.sol";

import {FactoryCollybusDiscountRateRelayer} from "src/factory/FactoryCollybusDiscountRateRelayer.sol";

import {CollybusDiscountRateRelayer} from "src/relayer/CollybusDiscountRate/CollybusDiscountRateRelayer.sol";

contract FactoryCollybusDiscountRateRelayerTest is DSTest {
    FactoryCollybusDiscountRateRelayer private _factory;

    address private _collybusAddress = address(0xC011805);

    function setUp() public {
        _factory = new FactoryCollybusDiscountRateRelayer();
    }

    function test_deploy() public {
        assertTrue(address(_factory) != address(0));
    }

    function test_create() public {
        address oracleAddress = _factory.create(_collybusAddress);

        assertTrue(
            oracleAddress != address(0),
            "Factory CollybusDiscountRateRelayer create failed"
        );
    }

    function test_create_validateProperties() public {
        address oracleAddress = _factory.create(_collybusAddress);

        assertEq(
            CollybusDiscountRateRelayer(oracleAddress).collybus(),
            _collybusAddress,
            "Factory CollybusDiscountRateRelayer incorrect collybus"
        );
    }

    function test_create_AddsPermission_OnSender() public {
        address oracle = _factory.create(_collybusAddress);

        assertTrue(
            CollybusDiscountRateRelayer(oracle).canCall(
                CollybusDiscountRateRelayer(oracle).ANY_SIG(),
                address(this)
            ),
            "Creator shold have admin access"
        );
    }
}
