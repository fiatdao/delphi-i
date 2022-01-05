// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import {DSTest} from "ds-test/test.sol";

import {Caller} from "src/test/utils/Caller.sol";

import {Pausable} from "src/pausable/Pausable.sol";

contract PausableInstance is Pausable {
    // This is set to true if execution was successful.
    // Use to check modifier execution.
    bool public executedSuccessfully;

    function check_whenNotPaused() public whenNotPaused {
        executedSuccessfully = true;
    }

    function check_whenPaused() public whenPaused {
        executedSuccessfully = true;
    }
}

contract PausableTest is DSTest {
    PausableInstance internal pausable;

    function setUp() public {
        pausable = new PausableInstance();
    }

    function test_Pause_Unpause() public {
        pausable.pause();
        assertTrue(pausable.paused() == true, "paused() should be true");

        pausable.unpause();
        assertTrue(pausable.paused() == false, "paused() should be false");
    }

    function test_WhenPaused_Success_When_Paused() public {
        pausable.pause();
        pausable.check_whenPaused();
        assertTrue(pausable.executedSuccessfully() == true);
    }

    function testFail_WhenPaused_Fails_When_NotPaused() public {
        // Starts as unpaused
        pausable.check_whenPaused();
    }

    function test_WhenNotPaused_Success_When_NotPaused() public {
        // Starts as unpaused
        pausable.check_whenNotPaused();
        assertTrue(pausable.executedSuccessfully() == true);
    }

    function testFail_WhenNotPaused_Fails_When_Paused() public {
        pausable.pause();
        pausable.check_whenNotPaused();
    }

    function test_PAUSER_ROLE_CanPauseUnpause() public {
        // Create a user
        Caller user = new Caller();

        // Grant PAUSER_ROLE to user
        pausable.grantRole(pausable.PAUSER_ROLE(), address(user));

        // Should be be able to pause
        user.externalCall(
            address(pausable),
            abi.encodeWithSelector(pausable.pause.selector)
        );

        // Contract is paused
        assertTrue(pausable.paused() == true, "paused() should be true");

        // Should be able to unpause
        user.externalCall(
            address(pausable),
            abi.encodeWithSelector(pausable.unpause.selector)
        );

        // Contract is unpaused
        assertTrue(pausable.paused() == false, "paused() should be false");
    }

    function test_NonPAUSER_ROLE_NotAbleToPause() public {
        // Create a user
        Caller user = new Caller();

        // Should not be able to pause
        bool success;
        (success, ) = user.externalCall(
            address(pausable),
            abi.encodeWithSelector(pausable.pause.selector)
        );
        assertTrue(success == false, "Should not be able to pause");

        // Contract is still unpaused
        assertTrue(pausable.paused() == false, "paused() should be false");
    }

    function test_NonPAUSER_ROLE_NotAbleToUnpause() public {
        // Create a user
        Caller user = new Caller();

        // Pause contract
        pausable.pause();

        // Should not be able to unpause
        bool success;
        (success, ) = user.externalCall(
            address(pausable),
            abi.encodeWithSelector(pausable.unpause.selector)
        );
        assertTrue(success == false, "Should not be able to unpause");

        // Contract is still paused
        assertTrue(pausable.paused(), "paused() should be false");
    }
}
