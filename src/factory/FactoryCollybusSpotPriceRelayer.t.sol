// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import "ds-test/test.sol";

import {MockProvider} from "@cleanunicorn/mockprovider/src/MockProvider.sol";

import {FactoryCollybusSpotPriceRelayer} from "src/factory/FactoryCollybusSpotPriceRelayer.sol";

import {CollybusSpotPriceRelayer} from "src/relayer/CollybusSpotPrice/CollybusSpotPriceRelayer.sol";

contract FactoryCollybusSpotPriceRelayerTest is DSTest {
    FactoryCollybusSpotPriceRelayer private _factory;

    address private _collybusAddress = address(0xC011805);

    function setUp() public {
        _factory = new FactoryCollybusSpotPriceRelayer();
    }

    function test_deploy() public {
        assertTrue(address(_factory) != address(0));
    }

    function test_create() public {
        address oracleAddress = _factory.create(_collybusAddress);

        assertTrue(
            oracleAddress != address(0),
            "Factory CollybusSpotPriceRelayer create failed"
        );
    }

    function test_create_checkCollybus() public {
        address oracleAddress = _factory.create(_collybusAddress);

        assertEq(
            CollybusSpotPriceRelayer(oracleAddress).collybus(),
            _collybusAddress,
            "Factory CollybusSpotPriceRelayer incorrect collybus"
        );
    }

    function test_create_AddsPermission_OnSender() public {
        address oracle = _factory.create(_collybusAddress);

        assertTrue(
            CollybusSpotPriceRelayer(oracle).canCall(
                CollybusSpotPriceRelayer(oracle).ANY_SIG(),
                address(this)
            ),
            "Creator shold have admin access"
        );
    }
}
