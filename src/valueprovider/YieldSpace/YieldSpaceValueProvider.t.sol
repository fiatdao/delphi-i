// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import "ds-test/test.sol";

import "src/test/utils/Caller.sol";
import {Hevm} from "src/test/utils/Hevm.sol";
import {MockProvider} from "src/test/utils/MockProvider.sol";
import {YieldSpaceValueProvider} from "./YieldSpaceValueProvider.sol";
import {IYieldSpacePool} from "./IYieldSpacePool.sol";

contract YieldSpaceTest is DSTest {
    Hevm internal hevm = Hevm(DSTest.HEVM_ADDRESS);

    MockProvider internal mockValueProvider;

    YieldSpaceValueProvider internal yieldSpaceVP;

    function setUp() public {
        mockValueProvider = new MockProvider();
        yieldSpaceVP = new YieldSpaceValueProvider(address(mockValueProvider));

        // Set the value returned by the pool contract
        // values taken from a YieldSpace Pool contract deployed at:
        // 0x3771c99c087a81df4633b50d8b149afaa83e3c9e at block 13911954
        mockValueProvider.givenQueryReturnResponse(
            abi.encodePacked(IYieldSpacePool.ts.selector),
            MockProvider.ReturnData({
                success: true,
                data: abi.encode(int128(58454204609))
            }),
            false
        );

        mockValueProvider.givenQueryReturnResponse(
            abi.encodePacked(IYieldSpacePool.getCache.selector),
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
        assertTrue(address(yieldSpaceVP) != address(0));
    }

    function test_GetValue() public {
        // Computed value based on the parameters that are sent via the mock provider
        int256 computedValue = 2072808605;
        int256 value = yieldSpaceVP.value();

        assertTrue(value == computedValue);
    }
}
