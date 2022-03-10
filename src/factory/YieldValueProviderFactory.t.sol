// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import "ds-test/test.sol";
import {MockProvider} from "@cleanunicorn/mockprovider/src/MockProvider.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {YieldValueProviderFactory} from "./YieldValueProviderFactory.sol";
import {IYieldPool} from "../oracle_implementations/discount_rate/Yield/IYieldPool.sol";
import {YieldValueProvider} from "../oracle_implementations/discount_rate/Yield/YieldValueProvider.sol";

contract YieldValueProviderFactoryTest is DSTest {
    uint256 private _oracleUpdateWindow;
    uint256 private _oracleMaxValidTime;
    int256 private _oracleAlpha = 1;

    uint256 private _maturity;
    int256 private _timeScale;

    YieldValueProviderFactory private _factory;

    function setUp() public {
        _factory = new YieldValueProviderFactory();
    }

    function test_deploy() public {
        assertTrue(address(_factory) != address(0));
    }

    function test_create() public {
        // Mock the yield pool that is needed when the value provider contract is created
        MockProvider yieldPool = new MockProvider();
        yieldPool.givenQueryReturnResponse(
            abi.encodeWithSelector(IYieldPool.getCache.selector),
            MockProvider.ReturnData({success: true, data: abi.encode(0, 0, 0)}),
            false
        );

        yieldPool.givenQueryReturnResponse(
            abi.encodeWithSelector(IYieldPool.cumulativeBalancesRatio.selector),
            MockProvider.ReturnData({success: true, data: abi.encode(0)}),
            false
        );

        // Create Yield Value Provider
        address yieldValueProviderAddress = _factory.create(
            _oracleUpdateWindow,
            _oracleMaxValidTime,
            _oracleAlpha,
            address(yieldPool),
            _maturity,
            _timeScale
        );

        assertTrue(
            yieldValueProviderAddress != address(0),
            "Factory Yield Value Provider create failed"
        );
    }

    function test_create_validateProperties() public {
        // Mock the yield pool that is needed when the value provider contract is created
        MockProvider yieldPool = new MockProvider();
        yieldPool.givenQueryReturnResponse(
            abi.encodeWithSelector(IYieldPool.getCache.selector),
            MockProvider.ReturnData({success: true, data: abi.encode(0, 0, 0)}),
            false
        );

        yieldPool.givenQueryReturnResponse(
            abi.encodeWithSelector(IYieldPool.cumulativeBalancesRatio.selector),
            MockProvider.ReturnData({success: true, data: abi.encode(0)}),
            false
        );

        // Create Yield Value Provider
        address yieldValueProviderAddress = _factory.create(
            _oracleUpdateWindow,
            _oracleMaxValidTime,
            _oracleAlpha,
            address(yieldPool),
            _maturity,
            _timeScale
        );

        // Test that properties are correctly set
        assertEq(
            YieldValueProvider(yieldValueProviderAddress).timeUpdateWindow(),
            _oracleUpdateWindow,
            "ElementFi Value Provider incorrect timeUpdateWindow"
        );

        assertEq(
            YieldValueProvider(yieldValueProviderAddress).maxValidTime(),
            _oracleMaxValidTime,
            "Yield Value Provider incorrect maxValidTime"
        );

        assertEq(
            YieldValueProvider(yieldValueProviderAddress).alpha(),
            _oracleAlpha,
            "Yield Value Provider incorrect alpha"
        );

        assertEq(
            YieldValueProvider(yieldValueProviderAddress).poolAddress(),
            address(yieldPool),
            "Yield Value Provider incorrect poolAddress"
        );

        assertEq(
            YieldValueProvider(yieldValueProviderAddress).maturity(),
            _maturity,
            "Yield Value Provider incorrect maturity"
        );

        assertEq(
            YieldValueProvider(yieldValueProviderAddress).timeScale(),
            _timeScale,
            "Yield Value Provider incorrect timeScale"
        );
    }
}
