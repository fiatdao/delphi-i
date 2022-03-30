// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import "ds-test/test.sol";

import {MockProvider} from "@cleanunicorn/mockprovider/src/MockProvider.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import {ChainlinkFactory} from "./ChainlinkFactory.sol";
import {Relayer} from "../relayer/Relayer.sol";
import {IRelayer} from "../relayer/IRelayer.sol";

import {ChainlinkValueProvider} from "../oracle_implementations/spot_price/Chainlink/ChainlinkValueProvider.sol";
import {IChainlinkAggregatorV3Interface} from "../oracle_implementations/spot_price/Chainlink/ChainlinkAggregatorV3Interface.sol";

contract ChainlinkFactoryTest is DSTest {
    address private _collybusAddress = address(0xC011b005);
    uint256 private _oracleUpdateWindow = 1 * 3600;
    address private _tokenAddress = address(0x105311);
    uint256 private _minimumPercentageDeltaValue = 25;

    ChainlinkFactory private _factory;

    function setUp() public {
        _factory = new ChainlinkFactory();
    }

    function test_deploy() public {
        assertTrue(address(_factory) != address(0));
    }

    function test_create_relayerIsDeployed() public {
        // Create a chainlink mock aggregator
        MockProvider chainlinkMock = new MockProvider();
        chainlinkMock.givenQueryReturnResponse(
            abi.encodeWithSelector(
                IChainlinkAggregatorV3Interface.decimals.selector
            ),
            MockProvider.ReturnData({success: true, data: abi.encode(8)}),
            false
        );

        // Create the chainlink Relayer
        address chainlinkRelayerAddress = _factory.create(
            _collybusAddress,
            _tokenAddress,
            _minimumPercentageDeltaValue,
            _oracleUpdateWindow,
            address(chainlinkMock)
        );

        assertTrue(
            chainlinkRelayerAddress != address(0),
            "Factory Chainlink Relayer create failed"
        );
    }

    function test_create_oracleIsDeployed() public {
        // Create a chainlink mock aggregator
        MockProvider chainlinkMock = new MockProvider();
        chainlinkMock.givenQueryReturnResponse(
            abi.encodeWithSelector(
                IChainlinkAggregatorV3Interface.decimals.selector
            ),
            MockProvider.ReturnData({success: true, data: abi.encode(8)}),
            false
        );

        // Create the chainlink Relayer
        address chainlinkRelayerAddress = _factory.create(
            _collybusAddress,
            _tokenAddress,
            _minimumPercentageDeltaValue,
            _oracleUpdateWindow,
            address(chainlinkMock)
        );

        assertTrue(
            Relayer(chainlinkRelayerAddress).oracle() != address(0),
            "Invalid oracle address"
        );
    }

    function test_create_validateRelayerProperties() public {
        // Create a chainlink mock aggregator
        MockProvider chainlinkMock = new MockProvider();
        chainlinkMock.givenQueryReturnResponse(
            abi.encodeWithSelector(
                IChainlinkAggregatorV3Interface.decimals.selector
            ),
            MockProvider.ReturnData({success: true, data: abi.encode(8)}),
            false
        );

        // Create the chainlink Relayer
        Relayer chainlinkRelayer = Relayer(
            _factory.create(
                _collybusAddress,
                _tokenAddress,
                _minimumPercentageDeltaValue,
                _oracleUpdateWindow,
                address(chainlinkMock)
            )
        );

        assertEq(
            Relayer(chainlinkRelayer).collybus(),
            _collybusAddress,
            "Chainlink Relayer incorrect Collybus address"
        );

        assertTrue(
            Relayer(chainlinkRelayer).relayerType() ==
                IRelayer.RelayerType.SpotPrice,
            "Chainlink Relayer incorrect RelayerType"
        );

        assertEq(
            Relayer(chainlinkRelayer).encodedTokenId(),
            bytes32(uint256(uint160(_tokenAddress))),
            "Chainlink Relayer incorrect tokenId"
        );

        assertEq(
            Relayer(chainlinkRelayer).minimumPercentageDeltaValue(),
            _minimumPercentageDeltaValue,
            "Chainlink Relayer incorrect minimumPercentageDeltaValue"
        );
    }

    function test_create_validateOracleProperties() public {
        // Create a chainlink mock aggregator
        MockProvider chainlinkMock = new MockProvider();
        chainlinkMock.givenQueryReturnResponse(
            abi.encodeWithSelector(
                IChainlinkAggregatorV3Interface.decimals.selector
            ),
            MockProvider.ReturnData({success: true, data: abi.encode(8)}),
            false
        );

        // Create the chainlink Relayer
        address chainlinkRelayerAddress = _factory.create(
            _collybusAddress,
            _tokenAddress,
            _minimumPercentageDeltaValue,
            _oracleUpdateWindow,
            address(chainlinkMock)
        );

        address chainlinkOracleAddress = Relayer(chainlinkRelayerAddress)
            .oracle();

        // Test that properties are correctly set
        assertEq(
            ChainlinkValueProvider(chainlinkOracleAddress).timeUpdateWindow(),
            _oracleUpdateWindow,
            "Chainlink Value Provider incorrect oracleUpdateWindow"
        );

        assertEq(
            ChainlinkValueProvider(chainlinkOracleAddress)
                .chainlinkAggregatorAddress(),
            address(chainlinkMock),
            "Chainlink Value Provider incorrect chainlinkAggregatorAddress"
        );
    }

    function test_create_factoryPassesOraclePermissions() public {
        // Create a chainlink mock aggregator
        MockProvider chainlinkMock = new MockProvider();
        chainlinkMock.givenQueryReturnResponse(
            abi.encodeWithSelector(
                IChainlinkAggregatorV3Interface.decimals.selector
            ),
            MockProvider.ReturnData({success: true, data: abi.encode(8)}),
            false
        );

        // Create chainlink Relayer
        address chainlinkRelayerAddress = _factory.create(
            _collybusAddress,
            _tokenAddress,
            _minimumPercentageDeltaValue,
            _oracleUpdateWindow,
            address(chainlinkMock)
        );

        ChainlinkValueProvider chainlinkValueProvider = ChainlinkValueProvider(
            Relayer(chainlinkRelayerAddress).oracle()
        );

        bool factoryIsAuthorized = chainlinkValueProvider.canCall(
            chainlinkValueProvider.ANY_SIG(),
            address(_factory)
        );
        assertTrue(
            factoryIsAuthorized == false,
            "The Factory should not have rights over the created contract"
        );

        bool callerIsAuthorized = chainlinkValueProvider.canCall(
            chainlinkValueProvider.ANY_SIG(),
            address(this)
        );
        assertTrue(
            callerIsAuthorized,
            "Caller should have rights over the created contract"
        );
    }

    function test_create_factoryPassesRelayerPermissions() public {
        // Create a chainlink mock aggregator
        MockProvider chainlinkMock = new MockProvider();
        chainlinkMock.givenQueryReturnResponse(
            abi.encodeWithSelector(
                IChainlinkAggregatorV3Interface.decimals.selector
            ),
            MockProvider.ReturnData({success: true, data: abi.encode(8)}),
            false
        );

        // Create chainlink Relayer
        Relayer chainlinkRelayer = Relayer(
            _factory.create(
                _collybusAddress,
                _tokenAddress,
                _minimumPercentageDeltaValue,
                _oracleUpdateWindow,
                address(chainlinkMock)
            )
        );

        bool factoryIsAuthorized = chainlinkRelayer.canCall(
            chainlinkRelayer.ANY_SIG(),
            address(_factory)
        );
        assertTrue(
            factoryIsAuthorized == false,
            "The Factory should not have rights over the created contract"
        );

        bool callerIsAuthorized = chainlinkRelayer.canCall(
            chainlinkRelayer.ANY_SIG(),
            address(this)
        );
        assertTrue(
            callerIsAuthorized,
            "Caller should have rights over the created contract"
        );
    }
}
