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

    function setUp() public {
        mockValueProvider = new MockProvider();
        yieldVP = new YieldValueProvider(address(mockValueProvider));

        // Set the value returned by the pool contract
        // values taken from a Yield Pool contract deployed at:
        // 0x3771c99c087a81df4633b50d8b149afaa83e3c9e at block 13911954
        mockValueProvider.givenQueryReturnResponse(
            abi.encodePacked(IYieldPool.ts.selector),
            MockProvider.ReturnData({
                success: true,
                data: abi.encode(int128(58454204609))
            }),
            false
        );

        mockValueProvider.givenQueryReturnResponse(
            abi.encodePacked(IYieldPool.getCache.selector),
            MockProvider.ReturnData({
                success: true,
                data: abi.encode(
                    uint112(68427375273295066088),
                    uint112(131617714153224459945),
                    uint32(1640937617)
                )
            }),
            false
        );
    }

    function test_deploy() public {
        assertTrue(address(yieldVP) != address(0));
    }

    function test_GetValue() public {
        // Computed value based on the parameters that are sent via the mock provider
        int256 computedValue = 2072808605;
        int256 value = yieldVP.value();

        assertTrue(value == computedValue);
    }
}
