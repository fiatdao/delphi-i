// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import "ds-test/test.sol";
import {Caller} from "../test/utils/Caller.sol";
import {Guarded} from "../guarded/Guarded.sol";
import {MockProvider} from "@cleanunicorn/mockprovider/src/MockProvider.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {RelayerFactory} from "./RelayerFactory.sol";
import {Relayer} from "../relayer/Relayer.sol";
import {StaticRelayer} from "../relayer/StaticRelayer.sol";
import {IRelayer} from "../relayer/IRelayer.sol";

contract RelayerFactoryTest is DSTest {
    address private _collybusAddress = address(0x1);
    address private _oracleAddress = address(0x2);
    IRelayer.RelayerType private _relayerType =
        IRelayer.RelayerType.DiscountRate;
    bytes32 private _encodedTokenId = "encodedTokeId";
    uint256 private _minimumPercentageDeltaValue = 100_00;

    RelayerFactory private _factory;

    function setUp() public {
        _factory = new RelayerFactory();
    }

    function test_deploy() public {
        assertTrue(address(_factory) != address(0));
    }

    function test_create() public {
        // Create Relayer
        address relayerAddress = _factory.create(
            _collybusAddress,
            _relayerType,
            _oracleAddress,
            _encodedTokenId,
            _minimumPercentageDeltaValue
        );

        assertTrue(
            relayerAddress != address(0),
            "Factory Relayer create failed"
        );
    }

    function test_createStatic() public {
        // Create a static Relayer
        uint256 value = 1;
        address staticRelayerAddress = _factory.createStatic(
            _collybusAddress,
            _relayerType,
            _encodedTokenId,
            value
        );

        assertTrue(
            staticRelayerAddress != address(0),
            "Factory StaticRelayer create failed"
        );
    }

    function test_create_validateProperties() public {
        Relayer relayer = Relayer(
            _factory.create(
                _collybusAddress,
                _relayerType,
                _oracleAddress,
                _encodedTokenId,
                _minimumPercentageDeltaValue
            )
        );

        assertEq(
            relayer.collybus(),
            _collybusAddress,
            "Relayer incorrect collybus"
        );

        assertTrue(
            relayer.relayerType() == _relayerType,
            "Relayer incorrect relayerType"
        );

        assertEq(
            relayer.oracle(),
            _oracleAddress,
            "Relayer incorrect oracle address"
        );

        assertEq(
            relayer.encodedTokenId(),
            _encodedTokenId,
            "Relayer incorrect encoded token id"
        );

        assertEq(
            relayer.minimumPercentageDeltaValue(),
            _minimumPercentageDeltaValue,
            "Relayer incorrect minimumPercentageDeltaValue"
        );
    }

    function test_createStatic_validateProperties() public {
        uint256 value = 1;
        StaticRelayer staticRelayer = StaticRelayer(
            _factory.createStatic(
                _collybusAddress,
                _relayerType,
                _encodedTokenId,
                value
            )
        );

        assertEq(
            staticRelayer.collybus(),
            _collybusAddress,
            "StaticRelayer incorrect collybus"
        );

        assertTrue(
            staticRelayer.relayerType() == _relayerType,
            "StaticRelayer incorrect relayerType"
        );

        assertEq(
            staticRelayer.encodedTokenId(),
            _encodedTokenId,
            "StaticRelayer incorrect encoded token id"
        );

        assertEq(staticRelayer.value(), value, "StaticRelayer incorrect value");
    }

    function test_create_factoryPassesPermissions() public {
        Relayer relayer = Relayer(
            _factory.create(
                _collybusAddress,
                _relayerType,
                _oracleAddress,
                _encodedTokenId,
                _minimumPercentageDeltaValue
            )
        );

        bool factoryIsAuthorized = relayer.canCall(
            relayer.ANY_SIG(),
            address(_factory)
        );
        assertTrue(
            factoryIsAuthorized == false,
            "The Factory should not have rights over the created contract"
        );

        bool callerIsAuthorized = relayer.canCall(
            relayer.ANY_SIG(),
            address(this)
        );
        assertTrue(
            callerIsAuthorized,
            "Caller should have rights over the created contract"
        );
    }
}
