// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import "ds-test/test.sol";

import "src/test/utils/Caller.sol";
import {Hevm} from "src/test/utils/Hevm.sol";
import {MockProvider} from "src/test/utils/MockProvider.sol";
import {IValueProvider} from "src/valueprovider/IValueProvider.sol";

import {Oracle} from "./Oracle.sol";

contract OracleTest is DSTest {
    Hevm internal hevm = Hevm(DSTest.HEVM_ADDRESS);

    MockProvider internal mockValueProvider;

    Oracle internal oracle;
    uint256 internal timeUpdateWindow = 100; // seconds
    uint256 internal maxValidTime = 300;
    int256 internal alpha = 2 * 10**17; // 0.2

    function setUp() public {
        mockValueProvider = new MockProvider();
        oracle = new Oracle(
            address(mockValueProvider),
            timeUpdateWindow,
            maxValidTime,
            alpha
        );

        // Set the value returned by Value Provider to 100
        mockValueProvider.givenQueryReturnResponse(
            abi.encodePacked(IValueProvider.value.selector),
            MockProvider.ReturnData({
                success: true,
                data: abi.encode(int256(100 * 10**18))
            }),
            false
        );

        hevm.warp(timeUpdateWindow * 10);
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
        hevm.warp(blockTimestamp + timeUpdateWindow - 1);

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

        // Advance time
        hevm.warp(blockTimestamp + timeUpdateWindow);

        // Calling update should update the values
        // because enough time has passed
        oracle.update();

        // Last timestamp should be updated
        assertEq(oracle.lastTimestamp(), blockTimestamp + timeUpdateWindow);
    }

    function test_update_UpdateDoesNotChangeTheValue_InTheSameWindow() public {
        mockValueProvider.givenQueryReturnResponse(
            abi.encodePacked(IValueProvider.value.selector),
            MockProvider.ReturnData({
                success: true,
                data: abi.encode(int256(100 * 10**18))
            }),
            false
        );
        // Update the oracle
        oracle.update();

        (int256 value1, ) = oracle.value();
        assertEq(value1, 100 * 10**18);

        int256 nextValue1 = oracle.nextValue();
        assertEq(nextValue1, 100 * 10**18);

        mockValueProvider.givenQueryReturnResponse(
            abi.encodePacked(IValueProvider.value.selector),
            MockProvider.ReturnData({
                success: true,
                data: abi.encode(int256(150 * 10**18))
            }),
            false
        );

        // Advance time but stay in the same time update window
        hevm.warp(block.timestamp + 1);

        // Update the oracle
        oracle.update();

        // Values are not modified
        (int256 value2, ) = oracle.value();
        assertEq(value2, 100 * 10**18);

        int256 nextValue2 = oracle.nextValue();
        assertEq(nextValue2, 100 * 10**18);
    }

    function test_update_ShouldNotFailWhenValueProviderFails() public {
        mockValueProvider.givenQueryReturnResponse(
            abi.encodePacked(IValueProvider.value.selector),
            MockProvider.ReturnData({
                success: false,
                data: abi.encode(int256(10**18))
            }),
            false
        );

        // Update the oracle
        oracle.update();
    }

    function test_value_ShouldBeInvalidAfterValueProviderFails() public {
        // We first succesfully update the value to make sure the lastTimestamp is updated
        // After that, we wait for the required amount of time and try update the value again
        // The second update will fail and the value should be invalid because of the flag only.
        // (time check is still corect because maxValidTime >= timeUpdateWindow)

        mockValueProvider.givenQueryReturnResponse(
            abi.encodePacked(IValueProvider.value.selector),
            MockProvider.ReturnData({
                success: true,
                data: abi.encode(int256(10**18))
            }),
            false
        );

        // Update the oracle
        oracle.update();

        // Advance time
        hevm.warp(block.timestamp + timeUpdateWindow);

        mockValueProvider.givenQueryReturnResponse(
            abi.encodePacked(IValueProvider.value.selector),
            MockProvider.ReturnData({
                success: false,
                data: abi.encode(int256(10**18))
            }),
            false
        );

        // Update the oracle
        oracle.update();

        (, bool isValid) = oracle.value();
        assertTrue(isValid == false);
    }

    function test_value_ShouldBecomeValidAfterSuccesfullUpdate() public {
        mockValueProvider.givenQueryReturnResponse(
            abi.encodePacked(IValueProvider.value.selector),
            MockProvider.ReturnData({
                success: false,
                data: abi.encode(int256(10**18))
            }),
            false
        );

        oracle.update();

        (, bool isValid1) = oracle.value();
        assertTrue(isValid1 == false);

        mockValueProvider.givenQueryReturnResponse(
            abi.encodePacked(IValueProvider.value.selector),
            MockProvider.ReturnData({
                success: true,
                data: abi.encode(int256(10**18))
            }),
            false
        );

        oracle.update();

        (, bool isValid2) = oracle.value();
        assertTrue(isValid2 == true);
    }

    function test_update_Recalculates_MovingAverage() public {
        // Set the value to 100
        mockValueProvider.givenQueryReturnResponse(
            abi.encodePacked(IValueProvider.value.selector),
            MockProvider.ReturnData({
                success: true,
                data: abi.encode(int256(100 * 10**18))
            }),
            false
        );
        // Update the oracle
        oracle.update();

        // Check accumulated value
        (int256 value1, ) = oracle.value();
        // First update returns initial value
        assertEq(value1, 100 * 10**18);

        // Check next value
        int256 nextValue1 = oracle.nextValue();
        // Next value is set as the initial value
        assertEq(nextValue1, 100 * 10**18);

        // Set reported value to 150
        mockValueProvider.givenQueryReturnResponse(
            abi.encodePacked(IValueProvider.value.selector),
            MockProvider.ReturnData({
                success: true,
                data: abi.encode(int256(150 * 10**18))
            }),
            false
        );

        // Advance time
        hevm.warp(block.timestamp + timeUpdateWindow);

        // Update the oracle
        oracle.update();

        // Check value after the second update
        (int256 value2, ) = oracle.value();
        assertEq(value2, 100 * 10**18);

        // Check the next value after the second update
        int256 nextValue2 = oracle.nextValue();
        assertEq(nextValue2, 110 * 10**18);

        // Set reported value to 100
        mockValueProvider.givenQueryReturnResponse(
            abi.encodePacked(IValueProvider.value.selector),
            MockProvider.ReturnData({
                success: true,
                data: abi.encode(int256(100 * 10**18))
            }),
            false
        );

        // Advance time
        hevm.warp(block.timestamp + timeUpdateWindow);

        // Update the oracle
        oracle.update();

        (int256 value3, ) = oracle.value();
        assertEq(value3, 110 * 10**18);

        int256 nextValue3 = oracle.nextValue();
        assertEq(nextValue3, 108 * 10**18);
    }

    function test_ValueReturned_ShouldNotBeValid_IfNeverUpdated() public {
        // Initially the value should be considered stale
        (, bool valid) = oracle.value();
        assertTrue(valid == false);
    }

    function test_ValueReturned_ShouldNotBeValid_IfNotUpdatedForTooLong()
        public
    {
        // Set the value to 100
        mockValueProvider.givenQueryReturnResponse(
            abi.encodePacked(IValueProvider.value.selector),
            MockProvider.ReturnData({
                success: true,
                data: abi.encode(int256(100 * 10**18))
            }),
            false
        );
        // Update the oracle
        oracle.update();

        // Cache start time
        uint256 startTime = block.timestamp;

        // Advance time at the maximum valid time
        hevm.warp(startTime + maxValidTime - 1);
        // Check value , should be fresh
        (, bool valid1) = oracle.value();
        assertTrue(valid1 == true);

        // Advance time exactly when it should become invalid(or stale)
        hevm.warp(startTime + maxValidTime);
        // Check value, should be stale
        (, bool valid2) = oracle.value();
        assertTrue(valid2 == false);
    }

    function test_ValueReturned_ShouldBeValid_IfJustUpdated() public {
        // Update the oracle
        oracle.update();

        // Check stale value
        (, bool valid) = oracle.value();
        assertTrue(valid);
    }

    function test_Paused_Stops_ReturnValue() public {
        // Pause oracle
        oracle.pause();

        // Create user
        Caller user = new Caller();

        // Should fail trying to get value
        bool success;
        (success, ) = user.externalCall(
            address(oracle),
            abi.encodeWithSelector(oracle.value.selector)
        );

        assertTrue(success == false, "value() should fail when paused");
    }

    function test_Paused_DoesNotStop_Update() public {
        // Pause oracle
        oracle.pause();

        // Create user
        Caller user = new Caller();

        // Should not fail trying to get update
        bool success;
        (success, ) = user.externalCall(
            address(oracle),
            abi.encodeWithSelector(oracle.update.selector)
        );

        assertTrue(success, "update() should not fail when paused");
    }

    function test_Reset_ResetsContract() public {
        // Make sure there are some values in there
        oracle.update();

        // Last updated timestamp is this block
        assertEq(oracle.lastTimestamp(), block.timestamp);

        // Value should be 100 and valid
        int256 value;
        bool valid;
        (value, valid) = oracle.value();
        assertEq(value, 100 * 10**18);
        assertTrue(valid == true);

        // Oracle should be paused when resetting
        oracle.pause();

        // Reset contract
        oracle.reset();

        // Unpause contract
        oracle.unpause();

        // Last updated timestamp should be 0
        assertEq(oracle.lastTimestamp(), 0);

        // Value should be 0 and not valid
        (value, valid) = oracle.value();
        assertEq(value, 0);
        assertTrue(valid == false);

        // Next value should be 0
        assertEq(oracle.nextValue(), 0);
    }

    function test_Reset_ShouldBePossible_IfPaused() public {
        // Pause oracle
        oracle.pause();

        // Reset contract
        oracle.reset();
    }

    function testFail_Reset_ShouldNotBePossible_IfNotPaused() public {
        // Oracle is not paused
        assertTrue(oracle.paused() == false);

        // Reset contract should fail
        oracle.reset();
    }

    function test_AuthorizedUser_ShouldBeAble_ToReset() public {
        // Create user
        Caller user = new Caller();

        // Grant ability to reset
        oracle.allowCaller(oracle.reset.selector, address(user));

        // Oracle should be paused when calling reset
        oracle.pause();

        // Should not fail trying to reset
        bool success;
        (success, ) = user.externalCall(
            address(oracle),
            abi.encodeWithSelector(oracle.reset.selector)
        );

        assertTrue(
            success,
            "Only authorized user should be able to call reset()"
        );
    }

    function test_NonAuthorizedUser_ShouldNotBeAble_ToReset() public {
        // Create user
        // Do not authorize user
        Caller user = new Caller();

        // Oracle should be paused when calling reset
        oracle.pause();

        // Should fail trying to reset
        bool success;
        (success, ) = user.externalCall(
            address(oracle),
            abi.encodeWithSelector(oracle.reset.selector)
        );

        assertTrue(
            success == false,
            "Non-authorized user should not be able to call reset()"
        );
    }
}