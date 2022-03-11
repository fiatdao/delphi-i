// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import "ds-test/test.sol";
import "../test/utils/Caller.sol";
import {Hevm} from "../test/utils/Hevm.sol";
import {Oracle} from "./Oracle.sol";

contract OracleImplementation is Oracle {
    constructor(
        uint256 timeUpdateWindow_,
        uint256 maxValidTime_,
        int256 alpha_
    ) Oracle(timeUpdateWindow_, maxValidTime_, alpha_) {
        this;
    }

    // Allow the test to change the return value
    // This will not be used in the actual implementation
    int256 internal _returnValue;

    function setValue(int256 value_) public {
        _returnValue = value_;
    }

    // We want to handle cases where the oracle fails to obtain values
    // Ideally the `getValue()` will never fail, but the current implementation will also handle fails
    bool internal _success = true;

    function setSuccess(bool success_) public {
        _success = success_;
    }

    // We mock this value provider to return the expected previously set value
    function getValue() external view override(Oracle) returns (int256) {
        if (_success) {
            return _returnValue;
        } else {
            revert("Oracle failed");
        }
    }
}

contract OracleReenter is Oracle {
    constructor(
        uint256 timeUpdateWindow_,
        uint256 maxValidTime_,
        int256 alpha_
    ) Oracle(timeUpdateWindow_, maxValidTime_, alpha_) {
        this;
    }

    bool public reentered = false;

    function getValue() external override(Oracle) returns (int256) {
        if (reentered) {
            return 42;
        } else {
            reentered = true;
            super.update();
        }
    }
}

contract OracleTest is DSTest {
    Hevm internal hevm = Hevm(DSTest.HEVM_ADDRESS);

    OracleImplementation internal oracle;
    uint256 internal timeUpdateWindow = 100; // seconds
    uint256 internal maxValidTime = 300;
    int256 internal alpha = 2 * 10**17; // 0.2

    function setUp() public {
        oracle = new OracleImplementation(
            timeUpdateWindow,
            maxValidTime,
            alpha
        );

        // Set the value returned to 100
        oracle.setValue(int256(100 * 10**18));

        hevm.warp(timeUpdateWindow * 10);
    }

    function test_deploy() public {
        assertTrue(address(oracle) != address(0));
    }

    function test_check_timeUpdateWindow() public {
        // Check that the property was properly set
        assertTrue(
            oracle.timeUpdateWindow() == timeUpdateWindow,
            "Invalid oracle timeUpdateWindow"
        );
    }

    function test_check_maxValidTime() public {
        // Check that the property was properly set
        assertTrue(
            oracle.maxValidTime() == maxValidTime,
            "Invalid oracle maxValidTime"
        );
    }

    function test_check_alpha() public {
        // Check that the property was properly set
        assertTrue(oracle.alpha() == alpha, "Invalid oracle alpha");
    }

    function test_update_updates_timestamp() public {
        oracle.update();

        // Check if the timestamp was updated
        assertEq(oracle.lastTimestamp(), block.timestamp);
    }

    function test_update_shouldNotUpdatePreviousValues_ifNotEnoughTimePassed()
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

    function test_update_shouldUpdatePreviousValues_ifEnoughTimePassed()
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

    function test_update_updateDoesNotChangeTheValue_inTheSameWindow() public {
        oracle.setValue(int256(100 * 10**18));

        // Update the oracle
        oracle.update();

        (int256 value1, ) = oracle.value();
        assertEq(value1, 100 * 10**18);

        int256 nextValue1 = oracle.nextValue();
        assertEq(nextValue1, 100 * 10**18);

        oracle.setValue(int256(150 * 10**18));

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

    function test_update_shouldNotFail_whenValueProviderFails() public {
        oracle.setSuccess(false);

        // Update the oracle
        oracle.update();
    }

    function test_value_shouldBeInvalid_afterValueProviderFails() public {
        // We first successfully update the value to make sure the lastTimestamp is updated
        // After that, we wait for the required amount of time and try update the value again
        // The second update will fail and the value should be invalid because of the flag only.
        // (time check is still correct because maxValidTime >= timeUpdateWindow)

        oracle.setValue(10**18);

        // Update the oracle
        oracle.update();

        // Advance time
        hevm.warp(block.timestamp + timeUpdateWindow);

        oracle.setSuccess(false);

        // Update the oracle
        oracle.update();

        (, bool isValid) = oracle.value();
        assertTrue(isValid == false);
    }

    function test_value_shouldBecomeValid_afterSuccessfulUpdate() public {
        oracle.setSuccess(false);

        oracle.update();

        (, bool isValid1) = oracle.value();
        assertTrue(isValid1 == false);

        oracle.setSuccess(true);

        oracle.update();

        (, bool isValid2) = oracle.value();
        assertTrue(isValid2 == true);
    }

    function test_update_recalculates_movingAverage() public {
        // Set the value to 100
        oracle.setValue(100 * 10**18);
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
        oracle.setValue(150 * 10**18);

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
        oracle.setValue(100 * 10**18);

        // Advance time
        hevm.warp(block.timestamp + timeUpdateWindow);

        // Update the oracle
        oracle.update();

        (int256 value3, ) = oracle.value();
        assertEq(value3, 110 * 10**18);

        int256 nextValue3 = oracle.nextValue();
        assertEq(nextValue3, 108 * 10**18);
    }

    function test_valueReturned_shouldNotBeValid_ifNeverUpdated() public {
        // Initially the value should be considered stale
        (, bool valid) = oracle.value();
        assertTrue(valid == false);
    }

    function test_valueReturned_shouldNotBeValid_ifNotUpdatedForTooLong()
        public
    {
        // Set the value to 100
        oracle.setValue(100 * 10**18);
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

    function test_valueReturned_shouldBeValid_ifJustUpdated() public {
        // Update the oracle
        oracle.update();

        // Check stale value
        (, bool valid) = oracle.value();
        assertTrue(valid);
    }

    function test_paused_stops_returnValue() public {
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

    function test_paused_doesNotStop_update() public {
        // Pause oracle
        oracle.pause();

        // Create user
        Caller user = new Caller();

        // Allow user to call update on the oracle
        oracle.allowCaller(oracle.ANY_SIG(), address(user));

        // Should not fail trying to get update
        bool success;
        (success, ) = user.externalCall(
            address(oracle),
            abi.encodeWithSelector(oracle.update.selector)
        );

        assertTrue(success, "update() should not fail when paused");
    }

    function test_reset_resetsContract() public {
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

    function test_reset_shouldBePossible_ifPaused() public {
        // Pause oracle
        oracle.pause();

        // Reset contract
        oracle.reset();
    }

    function testFail_reset_shouldNotBePossible_ifNotPaused() public {
        // Oracle is not paused
        assertTrue(oracle.paused() == false);

        // Reset contract should fail
        oracle.reset();
    }

    function test_authorizedUser_shouldBeAble_toReset() public {
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

    function test_nonAuthorizedUser_shouldNotBeAble_toReset() public {
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

    function testFail_alphaHasToBe_greaterThanZero() public {
        new OracleImplementation(timeUpdateWindow, maxValidTime, 0);
    }

    function testFail_alphaHasToBe_lowerOrEqualToOne() public {
        new OracleImplementation(
            timeUpdateWindow,
            maxValidTime,
            1 * 10**18 + 1
        );
    }

    function testFail_update_cannotBeReentered() public {
        OracleReenter oracleReenter = new OracleReenter(
            timeUpdateWindow,
            maxValidTime,
            alpha
        );

        oracleReenter.update();

        assertTrue(oracleReenter.reentered());
    }

    function test_update_returnsTrue_whenSuccessful() public {
        bool updated;
        updated = oracle.update();

        assertTrue(updated, "Should return `true` no successful update");
    }

    function test_update_returnsFalse_whenUpdateDoesNotChangeAnything() public {
        bool updated;
        updated = oracle.update();

        // Second update should return false since it doesn't change anything
        updated = oracle.update();

        assertTrue(
            updated == false,
            "Should return `true` no successful update"
        );
    }

    function test_update_nonAuthorizedUserCanNotCall_update() public {
        Caller user = new Caller();

        // A non permissioned user should not be able to call
        bool ok;
        (ok, ) = user.externalCall(
            address(oracle),
            abi.encodeWithSelector(oracle.update.selector)
        );
        assertTrue(
            ok == false,
            "Non permissioned user should not be able to call update"
        );
    }

    function test_update_authorizedUserCanCall_update() public {
        Caller user = new Caller();

        // Give permission to the user
        oracle.allowCaller(oracle.update.selector, address(user));

        // A non permissioned user should not be able to call
        bool ok;
        (ok, ) = user.externalCall(
            address(oracle),
            abi.encodeWithSelector(oracle.update.selector)
        );
        assertTrue(ok, "Permissioned user should be able to call update");
    }
}
