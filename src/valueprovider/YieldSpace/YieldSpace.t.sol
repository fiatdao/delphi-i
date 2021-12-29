// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import "ds-test/test.sol";

import "src/test/utils/Caller.sol";
import {Hevm} from "src/test/utils/Hevm.sol";
import {MockProvider} from "src/test/utils/MockProvider.sol";
import {YieldSpace} from "./YieldSpace.sol";
import {IYieldSpacePool} from "./IYieldSpacePool.sol";

contract YieldSpaceTest is DSTest {
    Hevm internal hevm = Hevm(DSTest.HEVM_ADDRESS);

    MockProvider internal mockValueProvider;

    YieldSpace internal yieldSpace;

    function setUp() public {
        mockValueProvider = new MockProvider();
        yieldSpace = new YieldSpace(
            address(mockValueProvider)
        );

        // Set the value returned by the pool contract
        // value taken from contract deployed at:
        // 0x3771c99c087a81df4633b50d8b149afaa83e3c9e
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
                data: abi.encode(uint112(549300157691234827932610),
                                uint112(1054193133195781860970253),
                                uint32(1640609157))
            }),
            false
        );
    }

    function test_deploy() public {
        assertTrue(address(yieldSpace) != address(0));
    }

    function test_GetValue() public{

        int256 computedValue = 2065701839;
        int256 value = yieldSpace.value();

        assertTrue(value == computedValue);
    }
}
