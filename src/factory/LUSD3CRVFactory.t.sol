// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import "ds-test/test.sol";

import {MockProvider} from "@cleanunicorn/mockprovider/src/MockProvider.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import {ICurvePool} from "../oracle_implementations/spot_price/Chainlink/LUSD3CRV/ICurvePool.sol";
import {LUSD3CRVFactory} from "./LUSD3CRVFactory.sol";
import {Relayer} from "../relayer/Relayer.sol";
import {IRelayer} from "../relayer/IRelayer.sol";

import {LUSD3CRVValueProvider} from "../oracle_implementations/spot_price/Chainlink/LUSD3CRV/LUSD3CRVValueProvider.sol";
import {IChainlinkAggregatorV3Interface} from "../oracle_implementations/spot_price/Chainlink/ChainlinkAggregatorV3Interface.sol";

contract LUSD3CRVFactoryTest is DSTest {
    address private _collybusAddress = address(0xC011b005);
    uint256 private _oracleUpdateWindow = 1 * 3600;
    uint256 private _minimumPercentageDeltaValue = 25;

    address private _lusd3crvRelayerAddress;

    LUSD3CRVFactory private _factory;

    function setUp() public {
        _factory = new LUSD3CRVFactory();

        // Create a chainlink mock aggregator
        MockProvider chainlinkMock = new MockProvider();
        chainlinkMock.givenQueryReturnResponse(
            abi.encodeWithSelector(
                IChainlinkAggregatorV3Interface.decimals.selector
            ),
            MockProvider.ReturnData({success: true, data: abi.encode(8)}),
            false
        );

        MockProvider curveTokenMock = new MockProvider();
        curveTokenMock.givenQueryReturnResponse(
            abi.encodeWithSelector(ERC20.decimals.selector),
            MockProvider.ReturnData({success: true, data: abi.encode(18)}),
            false
        );

        // We can use a random curve 3pool address
        address curve3PoolAddress = address(0xC1133);
        // Create the Relayer
        _lusd3crvRelayerAddress = _factory.create(
            _collybusAddress,
            address(curveTokenMock),
            _minimumPercentageDeltaValue,
            _oracleUpdateWindow,
            curve3PoolAddress,
            address(curveTokenMock),
            address(chainlinkMock),
            address(chainlinkMock),
            address(chainlinkMock),
            address(chainlinkMock)
        );
    }

    function test_deploy() public {
        assertTrue(address(_factory) != address(0));
    }

    function test_create_relayerIsDeployed() public {
        assertTrue(
            _lusd3crvRelayerAddress != address(0),
            "Factory LUSD3CRV Relayer create failed"
        );
    }

    function test_create_oracleIsDeployed() public {
        assertTrue(
            Relayer(_lusd3crvRelayerAddress).oracle() != address(0),
            "Invalid oracle address"
        );
    }

    function test_create_validateRelayerProperties() public {
        assertEq(
            Relayer(_lusd3crvRelayerAddress).collybus(),
            _collybusAddress,
            "LUSD3CRV Relayer incorrect Collybus address"
        );

        assertTrue(
            Relayer(_lusd3crvRelayerAddress).relayerType() ==
                IRelayer.RelayerType.SpotPrice,
            "LUSD3CRV Relayer incorrect RelayerType"
        );

        assertTrue(
            Relayer(_lusd3crvRelayerAddress).encodedTokenId() != bytes32(0),
            "LUSD3CRV Relayer incorrect tokenId"
        );

        assertEq(
            Relayer(_lusd3crvRelayerAddress).minimumPercentageDeltaValue(),
            _minimumPercentageDeltaValue,
            "LUSD3CRV Relayer incorrect minimumPercentageDeltaValue"
        );
    }

    function test_create_validateOracleProperties() public {
        address oracleAddress = Relayer(_lusd3crvRelayerAddress).oracle();

        // Test that properties are correctly set
        assertEq(
            LUSD3CRVValueProvider(oracleAddress).timeUpdateWindow(),
            _oracleUpdateWindow,
            "LUSD3CRV Value Provider incorrect oracleUpdateWindow"
        );

        assertTrue(
            LUSD3CRVValueProvider(oracleAddress).curve3Pool() != address(0),
            "LUSD3CRV Value Provider incorrect curve3Pool"
        );

        assertTrue(
            LUSD3CRVValueProvider(oracleAddress).curveLUSD3Pool() != address(0),
            "LUSD3CRV Value Provider incorrect curveLUSD3Pool"
        );

        assertTrue(
            LUSD3CRVValueProvider(oracleAddress).chainlinkLUSD() != address(0),
            "LUSD3CRV Value Provider incorrect chainlinkLUSD"
        );

        assertTrue(
            LUSD3CRVValueProvider(oracleAddress).chainlinkUSDC() != address(0),
            "LUSD3CRV Value Provider incorrect chainlinkUSDC"
        );

        assertTrue(
            LUSD3CRVValueProvider(oracleAddress).chainlinkDAI() != address(0),
            "LUSD3CRV Value Provider incorrect chainlinkDAI"
        );

        assertTrue(
            LUSD3CRVValueProvider(oracleAddress).chainlinkUSDT() != address(0),
            "LUSD3CRV Value Provider incorrect chainlinkUSDT"
        );
    }

    function test_create_factoryPassesOraclePermissions() public {
        LUSD3CRVValueProvider lusd3crvValueProvider = LUSD3CRVValueProvider(
            Relayer(_lusd3crvRelayerAddress).oracle()
        );

        bool factoryIsAuthorized = lusd3crvValueProvider.canCall(
            lusd3crvValueProvider.ANY_SIG(),
            address(_factory)
        );
        assertTrue(
            factoryIsAuthorized == false,
            "The Factory should not have rights over the created contract"
        );

        bool callerIsAuthorized = lusd3crvValueProvider.canCall(
            lusd3crvValueProvider.ANY_SIG(),
            address(this)
        );
        assertTrue(
            callerIsAuthorized,
            "Caller should have rights over the created contract"
        );
    }

    function test_create_factoryPassesRelayerPermissions() public {
        Relayer relayer = Relayer(_lusd3crvRelayerAddress);
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
