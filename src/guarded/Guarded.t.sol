// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import {DSTest} from "ds-test/test.sol";

import {Caller} from "src/test/utils/Caller.sol";

import {Guarded} from "src/guarded/Guarded.sol";

contract GuardedInstance is Guarded {
    constructor() Guarded() {}

    function guardedMethod() external checkCaller {}

    function guardedMethodRoot() external checkCaller {}
}

contract GuardedTest is DSTest {
    GuardedInstance guarded;

    function setUp() public {
        guarded = new GuardedInstance();
    }

    function test_custom_role() public {
        Caller user = new Caller();
        bool ok;
        bool canCall;

        // Should not be able to call method
        (ok, ) = user.externalCall(address(guarded), abi.encodeWithSelector(guarded.guardedMethod.selector));
        assertTrue(ok == false, "Cannot call guarded method before adding permissions");

        // Adding permission should allow user to call method
        guarded.allowCaller(guarded.guardedMethod.selector, address(user));
        (ok, ) = user.externalCall(address(guarded), abi.encodeWithSelector(guarded.guardedMethod.selector));
        assertTrue(ok, "Can call method after adding permissions");

        // User has custom permission to call method
        canCall = guarded.canCall(guarded.guardedMethod.selector, address(user));
        assertTrue(canCall, "User has permission");

        // Removing role disables permission
        guarded.blockCaller(guarded.guardedMethod.selector, address(user));
        (ok, ) = user.externalCall(address(guarded), abi.encodeWithSelector(guarded.guardedMethod.selector));
        assertTrue(ok == false, "Cannot call method after removing permissions");

        // User does not have custom role
        canCall = guarded.canCall(guarded.guardedMethod.selector, address(user));
        assertTrue(canCall == false, "User does not have permission");
    }

    function test_root_role() public {
        Caller user = new Caller();
        bool ok;

        // Should not be able to call method
        (ok, ) = user.externalCall(address(guarded), abi.encodeWithSelector(guarded.guardedMethodRoot.selector));
        assertTrue(ok == false, "Root can call method");

        // Adding ANY_SIG should allow user to call method
        guarded.allowCaller(guarded.ANY_SIG(), address(user));
        (ok, ) = user.externalCall(address(guarded), abi.encodeWithSelector(guarded.guardedMethodRoot.selector));
        assertTrue(ok, "User can call method after adding root permissions");

        // User has senatus role
        bool canCall = guarded.canCall(guarded.ANY_SIG(), address(user));
        assertTrue(canCall, "User has permission");

        // Removing senatus role disables permission
        guarded.blockCaller(guarded.ANY_SIG(), address(user));
        (ok, ) = user.externalCall(address(guarded), abi.encodeWithSelector(guarded.guardedMethodRoot.selector));
        assertTrue(ok == false, "Senatus cannot call method after removing permissions");

        // User does not have senatus role
        canCall = guarded.canCall(guarded.ANY_SIG(), address(user));
        assertTrue(canCall == false, "User does not have role");
    }

    function test_root_has_god_mode_access() public {
        Caller user = new Caller();
        bool ok;

        // Should not be able to call method
        (ok, ) = user.externalCall(address(guarded), abi.encodeWithSelector(guarded.guardedMethod.selector));
        assertTrue(ok == false, "Cannot call guarded method before adding permissions");

        // Adding senatus role should allow user to call method
        guarded.allowCaller(guarded.ANY_SIG(), address(user));
        (ok, ) = user.externalCall(address(guarded), abi.encodeWithSelector(guarded.guardedMethod.selector));
        assertTrue(ok, "Can call method after adding senatus role");
    }
}
