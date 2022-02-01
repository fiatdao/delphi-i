// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import "ds-test/test.sol";

import "src/test/utils/Caller.sol";
import {Hevm} from "src/test/utils/Hevm.sol";
import {MockProvider} from "src/test/utils/MockProvider.sol";
import {YieldValueProvider} from "./YieldValueProvider.sol";
import {IYieldPool} from "./IYieldPool.sol";

contract YieldValueProviderTest is DSTest {
    Hevm internal hevm = Hevm(DSTest.HEVM_ADDRESS);

    MockProvider internal mockValueProvider;

    YieldValueProvider internal yieldVP;

    uint256 maturity = 1648177200;
    int256 timeScale = 3168808781;
    uint112 baseReserve = 2129533588416199172581255;
    uint112 fyReserve = 2303024699021990246792971;
    uint32 blockTime = 1643281604;

    function setUp() public {
        createWithValues(
            maturity,
            timeScale, // 58454204609 in 64.64 format
            baseReserve,
            fyReserve,
            blockTime
        );
    }

    function createWithValues(
        uint256 maturity_,
        int256 timeScale_,
        uint112 baseReserve_,
        uint112 fyReserve_,
        uint32 blocktime_
    ) public {
        mockValueProvider = new MockProvider();
        yieldVP = new YieldValueProvider(
            address(mockValueProvider),
            uint256(maturity_),
            int256(timeScale_)
        );

        // Set the value returned by the pool contract
        mockValueProvider.givenQueryReturnResponse(
            abi.encodePacked(IYieldPool.getCache.selector),
            MockProvider.ReturnData({
                success: true,
                data: abi.encode(baseReserve_, fyReserve_, blocktime_)
            }),
            false
        );
    }

    function test_deploy() public {
        assertTrue(address(yieldVP) != address(0), "Yield value provider should be deployed");
    }

    function test_check_poolId() public {
        assertTrue(
            yieldVP.poolAddress() != address(0),
            "Yield pool address should be valid"
        );
    }

    function test_check_maturity() public{
        assertEq(
            yieldVP.maturity(),
            maturity,
            "Invalid maturity date"
        );
    }

    function test_check_timeScale() public{
        assertEq(
            yieldVP.timeScale(),
            timeScale,
            "Invalid time scale value"
        );
    }

    function test_GetValue() public {
        // Compute example 1 from:
        // https://colab.research.google.com/drive/1RYGuGQW3RcRlYkk2JKy6FeEouvr77gFV#scrollTo=ccEQ0z8xF0L4
        int256 expectedValue = 248182251;
        int256 value = yieldVP.value();
        assertTrue(value == expectedValue);
    }
}
