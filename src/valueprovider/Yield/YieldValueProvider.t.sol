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

    function createWithValues(
        uint256 maturity,
        int256 timeScale,
        uint112 baseReserve,
        uint112 fyReserve,
        uint32 blocktime
    ) public {
        mockValueProvider = new MockProvider();
        yieldVP = new YieldValueProvider(
            address(mockValueProvider),
            uint256(maturity),
            int256(timeScale)
        );

        // Set the value returned by the pool contract
        mockValueProvider.givenQueryReturnResponse(
            abi.encodePacked(IYieldPool.getCache.selector),
            MockProvider.ReturnData({
                success: true,
                data: abi.encode(baseReserve, fyReserve, blocktime)
            }),
            false
        );
    }

    function test_deploy() public {
        createWithValues(
            uint256(1648177200),
            int256(3168808781),// 58454204609 in 64.64 format
            uint112(2129533588416199172581255),
            uint112(2303024699021990246792971),
            uint32(1643281604)
        );
        assertTrue(address(yieldVP) != address(0));
    }

    function test_GetValue() public {

        // Compute example 1 from:
        // https://colab.research.google.com/drive/1RYGuGQW3RcRlYkk2JKy6FeEouvr77gFV#scrollTo=ccEQ0z8xF0L4
        createWithValues(
            uint256(1648177200),
            int256(3168808781),// 58454204609 in 64.64 format
            uint112(2129533588416199172581255),
            uint112(2303024699021990246792971),
            uint32(1643281604)
        );

        int256 expectedValue = 248182251;
        int256 value = yieldVP.value();
        assertTrue(value == expectedValue);
    }
}
