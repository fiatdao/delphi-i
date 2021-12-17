// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import {DSTest} from "ds-test/test.sol";

import {Caller} from "./test/utils/Caller.sol";

import {Guarded} from "./Guarded.sol";

contract GuardedInstance is Guarded {
    bytes32 public constant TEST_ROLE = keccak256("TEST_ROLE");

    constructor() Guarded() {}

    function guardedMethodTestRole() external onlyRole(TEST_ROLE) {}

    function guardedRootRole() external onlyRoot {}
}

contract GuardedTest is DSTest {
    GuardedInstance guarded;

    function setUp() public {
        guarded = new GuardedInstance();
    }

    function test_custom_role() public {
        Caller user = new Caller();
        bool ok;
        bool hasRole;

        // Should not be able to call method
        (ok, ) = user.externalCall(
            address(guarded),
            abi.encodeWithSelector(guarded.guardedMethodTestRole.selector)
        );
        assertTrue(
            ok == false,
            "Cannot call guarded method before adding permissions"
        );

        // Adding role should allow user to call method
        guarded.grantRole(guarded.TEST_ROLE(), address(user));
        (ok, ) = user.externalCall(
            address(guarded),
            abi.encodeWithSelector(guarded.guardedMethodTestRole.selector)
        );
        assertTrue(ok, "Can call method after adding permissions");

        // User has custom role
        hasRole = guarded.hasRole(guarded.TEST_ROLE(), address(user));
        assertTrue(hasRole, "User has role");

        // Removing role disables permission
        guarded.revokeRole(guarded.TEST_ROLE(), address(user));
        (ok, ) = user.externalCall(
            address(guarded),
            abi.encodeWithSelector(guarded.guardedMethodTestRole.selector)
        );
        assertTrue(
            ok == false,
            "Cannot call method after removing permissions"
        );

        // User does not have custom role
        hasRole = guarded.hasRole(guarded.TEST_ROLE(), address(user));
        assertTrue(hasRole == false, "User does not have role");
    }

    function test_root_role() public {
        Caller user = new Caller();
        bool ok;

        // Should not be able to call method
        (ok, ) = user.externalCall(
            address(guarded),
            abi.encodeWithSelector(guarded.guardedRootRole.selector)
        );
        assertTrue(ok == false, "Senatus can call method");

        // Adding senatus role should allow user to call method
        guarded.grantRole(guarded.ROOT_ROLE(), address(user));
        (ok, ) = user.externalCall(
            address(guarded),
            abi.encodeWithSelector(guarded.guardedRootRole.selector)
        );
        assertTrue(ok, "Senatus can call method after adding permissions");

        // User has senatus role
        bool hasRole = guarded.hasRole(guarded.ROOT_ROLE(), address(user));
        assertTrue(hasRole, "User has role");

        // Removing senatus role disables permission
        guarded.revokeRole(guarded.ROOT_ROLE(), address(user));
        (ok, ) = user.externalCall(
            address(guarded),
            abi.encodeWithSelector(guarded.guardedRootRole.selector)
        );
        assertTrue(
            ok == false,
            "Senatus cannot call method after removing permissions"
        );

        // User does not have senatus role
        hasRole = guarded.hasRole(guarded.ROOT_ROLE(), address(user));
        assertTrue(hasRole == false, "User does not have role");
    }

    function test_root_has_god_mode_access() public {
        Caller user = new Caller();
        bool ok;

        // Should not be able to call method
        (ok, ) = user.externalCall(
            address(guarded),
            abi.encodeWithSelector(guarded.guardedMethodTestRole.selector)
        );
        assertTrue(
            ok == false,
            "Cannot call guarded method before adding permissions"
        );

        // Adding senatus role should allow user to call method
        guarded.grantRole(guarded.ROOT_ROLE(), address(user));
        (ok, ) = user.externalCall(
            address(guarded),
            abi.encodeWithSelector(guarded.guardedMethodTestRole.selector)
        );
        assertTrue(ok, "Can call method after adding senatus role");
    }
}
