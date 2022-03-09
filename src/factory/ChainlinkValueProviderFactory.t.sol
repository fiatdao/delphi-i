// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import "ds-test/test.sol";

import {MockProvider} from "@cleanunicorn/mockprovider/src/MockProvider.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import {ChainlinkValueProviderFactory} from "src/factory/ChainlinkValueProviderFactory.sol";

import {ChainLinkValueProvider} from "src/oracle_implementations/spot_price/Chainlink/ChainLinkValueProvider.sol";
import {IChainlinkAggregatorV3Interface} from "src/oracle_implementations/spot_price/Chainlink/ChainlinkAggregatorV3Interface.sol";

contract ChainlinkValueProviderFactoryTest is DSTest {
    uint256 private _oracleUpdateWindow;
    uint256 private _oracleMaxValidTime;
    int256 private _oracleAlpha = 1;

    ChainlinkValueProviderFactory private _factory;

    function setUp() public {
        _factory = new ChainlinkValueProviderFactory();
    }

    function test_deploy() public {
        assertTrue(address(_factory) != address(0));
    }

    function test_create() public {
        // Create a chainlink mock aggregator
        MockProvider chainlinkMock = new MockProvider();
        chainlinkMock.givenQueryReturnResponse(
            abi.encodeWithSelector(
                IChainlinkAggregatorV3Interface.decimals.selector
            ),
            MockProvider.ReturnData({success: true, data: abi.encode(8)}),
            false
        );

        // Create chainlink Value Provider
        address chainlinkValueProviderAddress = _factory.create(
            _oracleUpdateWindow,
            _oracleMaxValidTime,
            _oracleAlpha,
            address(chainlinkMock)
        );

        assertTrue(
            chainlinkValueProviderAddress != address(0),
            "Factory Chainlink Value Provider create failed"
        );
    }

    function test_create_validateProperties() public {
        // Create a chainlink mock aggregator
        MockProvider chainlinkMock = new MockProvider();
        chainlinkMock.givenQueryReturnResponse(
            abi.encodeWithSelector(
                IChainlinkAggregatorV3Interface.decimals.selector
            ),
            MockProvider.ReturnData({success: true, data: abi.encode(8)}),
            false
        );

        // Create chainlink Value Provider
        address chainlinkValueProviderAddress = _factory.create(
            _oracleUpdateWindow,
            _oracleMaxValidTime,
            _oracleAlpha,
            address(chainlinkMock)
        );

        // Test that properties are correctly set
        assertEq(
            ChainLinkValueProvider(chainlinkValueProviderAddress)
                .chainlinkAggregatorAddress(),
            address(chainlinkMock),
            "Chainlink Value Provider incorrect chainlinkAggregatorAddress"
        );
    }
}
