// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import "ds-test/test.sol";
import {MockProvider} from "@cleanunicorn/mockprovider/src/MockProvider.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {YieldFactory} from "./YieldFactory.sol";
import {IYieldPool} from "../oracle_implementations/discount_rate/Yield/IYieldPool.sol";
import {YieldValueProvider} from "../oracle_implementations/discount_rate/Yield/YieldValueProvider.sol";

import {Relayer} from "../relayer/Relayer.sol";
import {IRelayer} from "../relayer/IRelayer.sol";

contract YieldFactoryTest is DSTest {
    address private _collybusAddress = address(0xC011b005);
    uint256 private _oracleUpdateWindow = 1 * 3600;
    uint256 private _tokenId = 1;
    uint256 private _minimumPercentageDeltaValue = 25;

    uint256 private _maturity = 1648177200;
    int256 private _timeScale = 3168808781; // computed from 58454204609 which is in 64.64 format

    YieldFactory private _factory;

    function setUp() public {
        _factory = new YieldFactory();
    }

    function test_deploy() public {
        assertTrue(address(_factory) != address(0));
    }

    function test_create_relayerIsDeployed() public {
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

        // Create Yield Relayer
        address yieldRelayerAddress = _factory.create(
            _collybusAddress,
            _tokenId,
            _minimumPercentageDeltaValue,
            _oracleUpdateWindow,
            address(yieldPool),
            _maturity,
            _timeScale
        );

        assertTrue(
            yieldRelayerAddress != address(0),
            "Yield Relayer create failed"
        );
    }

    function test_create_oracleIsDeployed() public {
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

        // Create Yield Relayer
        address yieldRelayerAddress = _factory.create(
            _collybusAddress,
            _tokenId,
            _minimumPercentageDeltaValue,
            _oracleUpdateWindow,
            address(yieldPool),
            _maturity,
            _timeScale
        );

        assertTrue(
            Relayer(yieldRelayerAddress).oracle() != address(0),
            "Invalid oracle address"
        );
    }

    function test_create_validateOracleProperties() public {
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

        // Create Yield Relayer
        address yieldRelayerAddress = _factory.create(
            _collybusAddress,
            _tokenId,
            _minimumPercentageDeltaValue,
            _oracleUpdateWindow,
            address(yieldPool),
            _maturity,
            _timeScale
        );

        address yieldOracleAddress = Relayer(yieldRelayerAddress).oracle();

        // Test that properties are correctly set
        assertEq(
            YieldValueProvider(yieldOracleAddress).timeUpdateWindow(),
            _oracleUpdateWindow,
            "Yield Value Provider incorrect timeUpdateWindow"
        );

        assertEq(
            YieldValueProvider(yieldOracleAddress).poolAddress(),
            address(yieldPool),
            "Yield Value Provider incorrect poolAddress"
        );

        assertEq(
            YieldValueProvider(yieldOracleAddress).maturity(),
            _maturity,
            "Yield Value Provider incorrect maturity"
        );

        assertEq(
            YieldValueProvider(yieldOracleAddress).timeScale(),
            _timeScale,
            "Yield Value Provider incorrect timeScale"
        );
    }

    function test_create_validateRelayerProperties() public {
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

        // Create Yield Relayer
        address yieldRelayerAddress = _factory.create(
            _collybusAddress,
            _tokenId,
            _minimumPercentageDeltaValue,
            _oracleUpdateWindow,
            address(yieldPool),
            _maturity,
            _timeScale
        );

        // Test that properties are correctly set
        assertEq(
            Relayer(yieldRelayerAddress).collybus(),
            _collybusAddress,
            "Yield Relayer incorrect Collybus address"
        );

        assertTrue(
            Relayer(yieldRelayerAddress).relayerType() ==
                IRelayer.RelayerType.DiscountRate,
            "Yield Relayer incorrect RelayerType"
        );

        assertEq(
            Relayer(yieldRelayerAddress).encodedTokenId(),
            bytes32(_tokenId),
            "Yield Relayer incorrect tokenId"
        );

        assertEq(
            Relayer(yieldRelayerAddress).minimumPercentageDeltaValue(),
            _minimumPercentageDeltaValue,
            "Yield Relayer incorrect minimumPercentageDeltaValue"
        );
    }

    function test_create_factoryPassesPermissions() public {
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

        // Create Yield Relayer
        address yieldRelayerAddress = _factory.create(
            _collybusAddress,
            _tokenId,
            _minimumPercentageDeltaValue,
            _oracleUpdateWindow,
            address(yieldPool),
            _maturity,
            _timeScale
        );

        YieldValueProvider yieldValueProvider = YieldValueProvider(
            Relayer(yieldRelayerAddress).oracle()
        );
        bool factoryIsAuthorized = yieldValueProvider.canCall(
            yieldValueProvider.ANY_SIG(),
            address(_factory)
        );
        assertTrue(
            factoryIsAuthorized == false,
            "The Factory should not have rights over the created contract"
        );

        bool callerIsAuthorized = yieldValueProvider.canCall(
            yieldValueProvider.ANY_SIG(),
            address(this)
        );
        assertTrue(
            callerIsAuthorized,
            "Caller should have rights over the created contract"
        );
    }
}
