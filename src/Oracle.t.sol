// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import "ds-test/test.sol";

import "./test/utils/Caller.sol";
import {Hevm} from "./test/utils/Hevm.sol";
import {MockProvider} from "./test/utils/MockProvider.sol";
import {IValueProvider} from "./valueprovider/IValueProvider.sol";

import {Oracle} from "./Oracle.sol";

contract OracleTest is DSTest {
    Hevm hevm = Hevm(DSTest.HEVM_ADDRESS);

    MockProvider mockValueProvider;

    Oracle oracle;
    uint256 minTimeBetweenWindows = 100; // seconds
    int256 alpha = 2 * 10**17; // 0.2

    function setUp() public {
        mockValueProvider = new MockProvider();
        oracle = new Oracle(
            address(mockValueProvider),
            minTimeBetweenWindows,
            alpha
        );

        // Set the value returned by Value Provider to 0
        mockValueProvider.givenQueryReturnResponse(
            abi.encodePacked(IValueProvider.value.selector),
            MockProvider.ReturnData({
                success: true,
                data: abi.encode(uint256(100 * 10**18))
            })
        );

        hevm.warp(minTimeBetweenWindows + 1);
    }

    function test_deploy() public {
        assertTrue(address(oracle) != address(0));
    }

    function test_update_Updates_timestamp() public {
        oracle.update();

        // Check if the timestamp was updated
        assertEq(oracle.lastTimestamp(), block.timestamp);
    }

    function test_update_ShouldNotUpdatePreviousValues_IfNotEnoughTimePassed()
        public
    {
        // Get current timestamp
        uint256 blockTimestamp = block.timestamp;

        // Update the oracle
        oracle.update();

        // Check if the timestamp was updated
        assertEq(oracle.lastTimestamp(), blockTimestamp);

        // Advance time
        hevm.warp(blockTimestamp + minTimeBetweenWindows - 1);

        // Calling update should not update the values
        // because not enough time has passed
        oracle.update();

        // Check if the values are still the same
        assertEq(oracle.lastTimestamp(), blockTimestamp);
    }

    function test_update_ShouldUpdatePreviousValues_IfEnoughTimePassed()
        public
    {
        // Get current timestamp
        uint256 blockTimestamp = block.timestamp;

        // Update the oracle
        oracle.update();

        // Check if the timestamp was updated
        assertEq(oracle.lastTimestamp(), blockTimestamp);

        // Advance time
        hevm.warp(blockTimestamp + minTimeBetweenWindows + 1);

        // Calling update should not update the values
        // because not enough time has passed
        oracle.update();

        // Check if the values are still the same
        assertEq(
            oracle.lastTimestamp(),
            blockTimestamp + minTimeBetweenWindows + 1
        );
    }

    function test_update_Recalculates_MovingAverage() public {
        // Set the value to 100
        mockValueProvider.givenQueryReturnResponse(
            abi.encodePacked(IValueProvider.value.selector),
            MockProvider.ReturnData({
                success: true,
                data: abi.encode(uint256(100 * 10**18))
            })
        );
        // Update the oracle
        oracle.update();

        // Check accumulated value
        int256 value1 = oracle.value();
        // First update returns initial value
        assertEq(value1, 100 * 10**18);

        // Set reported value to 150
        mockValueProvider.givenQueryReturnResponse(
            abi.encodePacked(IValueProvider.value.selector),
            MockProvider.ReturnData({
                success: true,
                data: abi.encode(uint256(150 * 10**18))
            })
        );

        // Advance time
        hevm.warp(block.timestamp + minTimeBetweenWindows);

        // Update the oracle
        oracle.update();

        // Check value after the second update
        int256 value2 = oracle.value();
        assertEq(value2, 110000000000000000000);

        // Set reported value to 100
        mockValueProvider.givenQueryReturnResponse(
            abi.encodePacked(IValueProvider.value.selector),
            MockProvider.ReturnData({
                success: true,
                data: abi.encode(uint256(100 * 10**18))
            })
        );

        // Advance time
        hevm.warp(block.timestamp + minTimeBetweenWindows);

        // Update the oracle
        oracle.update();

        // Check value after the third update
        int256 value3 = oracle.value();
        assertEq(value3, 108000000000000000000);
    }
}
