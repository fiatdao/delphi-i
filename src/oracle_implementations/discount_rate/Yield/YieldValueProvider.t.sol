// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import "ds-test/test.sol";

import "src/test/utils/Caller.sol";
import {Hevm} from "src/test/utils/Hevm.sol";
import {MockProvider} from "@cleanunicorn/mockprovider/src/MockProvider.sol";
import {YieldValueProvider} from "./YieldValueProvider.sol";
import {IYieldPool} from "./IYieldPool.sol";

contract YieldValueProviderTest is DSTest {
    Hevm internal hevm = Hevm(DSTest.HEVM_ADDRESS);

    MockProvider internal mockValueProvider;

    YieldValueProvider internal yieldVP;

    uint256 internal maturity = 1648177200;
    int256 internal timeScale = 3168808781; // 58454204609 in 64.64 format
    uint112 internal cumulativeBalancesRatio =
        5141501570599198210548627855691773;
    uint32 internal blockTime = 1639432842;

    uint256 internal _timeUpdateWindow = 100; // seconds
    uint256 internal _maxValidTime = 300;
    int256 internal _alpha = 2 * 10**17; // 0.2

    function setUp() public {
        mockValueProvider = new MockProvider();

        setMockValues(mockValueProvider, cumulativeBalancesRatio, blockTime);

        yieldVP = new YieldValueProvider(
            // Oracle arguments
            // Time update window
            _timeUpdateWindow,
            // Max valid time
            _maxValidTime,
            // Alpha
            _alpha,
            // Yield arguments
            address(mockValueProvider),
            uint256(maturity),
            int256(timeScale)
        );
    }

    function setMockValues(
        MockProvider mockValueProvider_,
        uint256 cumulativeBalancesRatio_,
        uint32 blocktime_
    ) public {
        // Set the  getCache values returned by the pool contract
        mockValueProvider_.givenQueryReturnResponse(
            abi.encodePacked(IYieldPool.getCache.selector),
            MockProvider.ReturnData({
                success: true,
                data: abi.encode(0, 0, blocktime_)
            }),
            false
        );

        // Set the cumulativeBalancesRatio returned by the pool contract
        mockValueProvider_.givenQueryReturnResponse(
            abi.encodePacked(IYieldPool.cumulativeBalancesRatio.selector),
            MockProvider.ReturnData({
                success: true,
                data: abi.encode(cumulativeBalancesRatio_)
            }),
            false
        );
    }

    function test_deploy() public {
        assertTrue(
            address(yieldVP) != address(0),
            "Yield value provider should be deployed"
        );
    }

    function test_check_poolId() public {
        assertTrue(
            yieldVP.poolAddress() != address(0),
            "Yield pool address should be valid"
        );
    }

    function test_check_maturity() public {
        assertEq(yieldVP.maturity(), maturity, "Invalid maturity date");
    }

    function test_check_timeScale() public {
        assertEq(yieldVP.timeScale(), timeScale, "Invalid time scale value");
    }

    function test_getValue() public {
        // Compute example 1 from:
        // https://colab.research.google.com/drive/1RYGuGQW3RcRlYkk2JKy6FeEouvr77gFV#scrollTo=ccEQ0z8xF0L4
        int256 expectedValue = 1204540138;
        setMockValues(
            mockValueProvider,
            7342183639948751441026554744281105,
            1640937617
        );
        int256 value = yieldVP.getValue();
        assertTrue(value == expectedValue);
    }
}
