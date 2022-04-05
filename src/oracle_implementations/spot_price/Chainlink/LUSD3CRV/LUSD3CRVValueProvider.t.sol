// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import "ds-test/test.sol";

import "../../../../test/utils/Caller.sol";
import {Hevm} from "../../../../test/utils/Hevm.sol";
import {MockProvider} from "@cleanunicorn/mockprovider/src/MockProvider.sol";

import {IChainlinkAggregatorV3Interface} from "../ChainlinkAggregatorV3Interface.sol";
import {LUSD3CRVValueProvider} from "./LUSD3CRVValueProvider.sol";
import {ICurvePool} from "./ICurvePool.sol";

contract LUSD3CRVValueProviderTest is DSTest {
    Hevm internal hevm = Hevm(DSTest.HEVM_ADDRESS);

    MockProvider internal curve3PoolMock;
    MockProvider internal curveLUSD3PoolMock;

    MockProvider internal mockChainlinkUSDC;
    MockProvider internal mockChainlinkDAI;
    MockProvider internal mockChainlinkUSDT;
    MockProvider internal mockChainlinkLUSD;

    int256 private _curve3poolVirtualPrice = 1020628557740573240;
    int256 private _lusd3PoolVirtualPrice = 1012508837937838125;

    int256 private _lusdPrice = 100102662;
    int256 private _usdcPrice = 100000298;
    int256 private _daiPrice = 100100000;
    int256 private _usdtPrice = 100030972;

    LUSD3CRVValueProvider internal chainlinkVP;

    uint256 private _timeUpdateWindow = 100; // seconds

    function initChainlinkMockProvider(
        MockProvider chainlinkMock_,
        int256 value_,
        uint256 decimals_
    ) private {
        chainlinkMock_.givenQueryReturnResponse(
            abi.encodeWithSelector(
                IChainlinkAggregatorV3Interface.latestRoundData.selector
            ),
            MockProvider.ReturnData({
                success: true,
                data: abi.encode(
                    uint80(36893488147419103548), // roundId
                    value_,
                    uint256(1642615905), // startedAt
                    uint256(1642615905), // updatedAt
                    uint80(36893488147419103548) // answeredInRound
                )
            }),
            false
        );
        chainlinkMock_.givenQueryReturnResponse(
            abi.encodeWithSelector(
                IChainlinkAggregatorV3Interface.decimals.selector
            ),
            MockProvider.ReturnData({
                success: true,
                data: abi.encode(decimals_)
            }),
            false
        );
    }

    function setUp() public {
        curve3PoolMock = new MockProvider();
        curve3PoolMock.givenQueryReturnResponse(
            abi.encodeWithSelector(ICurvePool.get_virtual_price.selector),
            MockProvider.ReturnData({
                success: true,
                data: abi.encode(_curve3poolVirtualPrice)
            }),
            false
        );

        curve3PoolMock.givenQueryReturnResponse(
            abi.encodeWithSelector(ICurvePool.decimals.selector),
            MockProvider.ReturnData({success: true, data: abi.encode(18)}),
            false
        );

        curveLUSD3PoolMock = new MockProvider();
        curveLUSD3PoolMock.givenQueryReturnResponse(
            abi.encodeWithSelector(ICurvePool.get_virtual_price.selector),
            MockProvider.ReturnData({
                success: true,
                data: abi.encode(_lusd3PoolVirtualPrice)
            }),
            false
        );

        curveLUSD3PoolMock.givenQueryReturnResponse(
            abi.encodeWithSelector(ICurvePool.decimals.selector),
            MockProvider.ReturnData({success: true, data: abi.encode(18)}),
            false
        );

        mockChainlinkLUSD = new MockProvider();
        initChainlinkMockProvider(mockChainlinkLUSD, _lusdPrice, 8);

        mockChainlinkUSDC = new MockProvider();
        initChainlinkMockProvider(mockChainlinkUSDC, _usdcPrice, 8);

        mockChainlinkDAI = new MockProvider();
        initChainlinkMockProvider(mockChainlinkDAI, _daiPrice, 8);

        mockChainlinkUSDT = new MockProvider();
        initChainlinkMockProvider(mockChainlinkUSDT, _usdtPrice, 8);

        chainlinkVP = new LUSD3CRVValueProvider(
            // Oracle arguments
            // Time update window
            _timeUpdateWindow,
            // Chainlink arguments
            address(curve3PoolMock),
            address(curveLUSD3PoolMock),
            address(mockChainlinkLUSD),
            address(mockChainlinkUSDC),
            address(mockChainlinkDAI),
            address(mockChainlinkUSDT)
        );
    }

    function test_deploy() public {
        assertTrue(address(chainlinkVP) != address(0));
    }

    function test_getValue() public {
        // Expected value is the value sent by the mock provider in 10**18 precision
        // The expect value was computed with this formula:
        // solhint-disable-next-line
        // https://www.wolframalpha.com/input?i2d=true&i=%5C%2840%29Divide%5B1012508837937838125%2CPower%5B10%2C18%5D%5D%5C%2841%29+*+minimum%5C%2840%29Divide%5B100102662%2CPower%5B10%2C8%5D%5D%5C%2844%29%5C%2840%29+Divide%5B1020628557740573240%2CPower%5B10%2C18%5D%5D+*+Divide%5Bminimum%5C%2840%29100030972%5C%2844%29100100000%5C%2844%29100000298%5C%2841%29%2CPower%5B10%2C8%5D%5D%5C%2841%29%5C%2841%29
        int256 expectedValue = 1013548299761041868;
        // Computed value based on the parameters that are sent via the mock provider
        int256 value = chainlinkVP.getValue();

        assertTrue(value == expectedValue);
    }

    function test_description() public {
        string memory expectedDescription = "LUSD3CRV";
        string memory desc = chainlinkVP.description();
        assertTrue(
            keccak256(abi.encodePacked(desc)) ==
                keccak256(abi.encodePacked(expectedDescription))
        );
    }

    function testFail_deploy_shouldFailWithInvalidLUSDPoolDecimals() public
    {
        curveLUSD3PoolMock.givenQueryReturnResponse(
            abi.encodeWithSelector(ICurvePool.decimals.selector),
            MockProvider.ReturnData({success: true, data: abi.encode(1)}),
            false
        );

        // Create should fail
        new LUSD3CRVValueProvider(
            // Oracle arguments
            // Time update window
            _timeUpdateWindow,
            // Chainlink arguments
            address(curve3PoolMock),
            address(curveLUSD3PoolMock),
            address(mockChainlinkLUSD),
            address(mockChainlinkUSDC),
            address(mockChainlinkDAI),
            address(mockChainlinkUSDT)
        );
    }

    function testFail_deploy_shouldFailWithInvalidCurve3PoolDecimals() public
    {
        curve3PoolMock.givenQueryReturnResponse(
            abi.encodeWithSelector(ICurvePool.decimals.selector),
            MockProvider.ReturnData({success: true, data: abi.encode(1)}),
            false
        );

        // Create should fail
        new LUSD3CRVValueProvider(
            // Oracle arguments
            // Time update window
            _timeUpdateWindow,
            // Chainlink arguments
            address(curve3PoolMock),
            address(curveLUSD3PoolMock),
            address(mockChainlinkLUSD),
            address(mockChainlinkUSDC),
            address(mockChainlinkDAI),
            address(mockChainlinkUSDT)
        );
    }
}
