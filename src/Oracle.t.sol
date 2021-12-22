// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import "ds-test/test.sol";

import "./test/utils/Caller.sol";
import {Hevm} from "./test/utils/Hevm.sol";
import {MockProvider} from "./test/utils/MockProvider.sol";
import {IValueProvider} from "./valueprovider/IValueProvider.sol";

import {Oracle} from "./Oracle.sol";

contract OracleTest is DSTest {
    Hevm internal hevm = Hevm(DSTest.HEVM_ADDRESS);

    MockProvider internal mockValueProvider;

    Oracle internal oracle;
    uint256 internal minTimeBetweenUpdates = 100; // seconds
    int256 internal alpha = 2 * 10**17; // 0.2

    function setUp() public {
        mockValueProvider = new MockProvider();
        oracle = new Oracle(
            address(mockValueProvider),
            minTimeBetweenUpdates,
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

        hevm.warp(minTimeBetweenUpdates * 10);
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
        hevm.warp(blockTimestamp + minTimeBetweenUpdates - 1);

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
        hevm.warp(blockTimestamp + minTimeBetweenUpdates + 1);

        // Calling update should not update the values
        // because not enough time has passed
        oracle.update();

        // Check if the values are still the same
        assertEq(
            oracle.lastTimestamp(),
            blockTimestamp + minTimeBetweenUpdates + 1
        );
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
        hevm.warp(block.timestamp + minTimeBetweenUpdates);

        // Update the oracle
        oracle.update();

        // Check value after the second update
        (int256 value2, ) = oracle.value();
        assertEq(value2, 110000000000000000000);

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
        hevm.warp(block.timestamp + minTimeBetweenUpdates);

        // Update the oracle
        oracle.update();

        // Check value after the third update
        (int256 value3, ) = oracle.value();
        assertEq(value3, 108000000000000000000);
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

        // Advance time
        hevm.warp(block.timestamp + minTimeBetweenUpdates * 2 + 1);

        // Check stale value
        (, bool valid) = oracle.value();
        assertTrue(valid == false);
    }

    function test_ValueReturned_ShouldBeValid_IfJustUpdated() public {
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

    function test_RESET_ROLE_ShouldBeAble_ToReset() public {
        // Create user
        Caller user = new Caller();

        // Grant RESET_ROLE to user
        oracle.grantRole(oracle.RESET_ROLE(), address(user));

        // Oracle should be paused when calling reset
        oracle.pause();

        // Should not fail trying to reset
        bool success;
        (success, ) = user.externalCall(
            address(oracle),
            abi.encodeWithSelector(oracle.reset.selector)
        );

        assertTrue(success, "RESET_ROLE should be able to call reset()");
    }

    function test_NonRESET_ROLE_ShouldNotBeAble_ToReset() public {
        // Create user
        // Do not grant RESET_ROLE to user
        Caller user = new Caller();

        // Oracle should be paused when calling reset
        oracle.pause();

        // Should fail trying to reset
        bool success;
        (success, ) = user.externalCall(
            address(oracle),
            abi.encodeWithSelector(oracle.reset.selector)
        );

        assertTrue(success == false, "Non-RESET_ROLE should not be able to call reset()");
    }
}
