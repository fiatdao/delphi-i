// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import "ds-test/test.sol";

import {Hevm} from "src/test/utils/Hevm.sol";
import {MockProvider} from "@cleanunicorn/mockprovider/src/MockProvider.sol";
import {Caller} from "src/test/utils/Caller.sol";
import {Guarded} from "src/guarded/Guarded.sol";

import {Oracle} from "src/oracle/Oracle.sol";
import {AggregatorOracle} from "src/aggregator/AggregatorOracle.sol";

contract AggregatorOracleTest is DSTest {
    Hevm internal hevm = Hevm(DSTest.HEVM_ADDRESS);

    AggregatorOracle internal aggregatorOracle;
    MockProvider internal oracle;

    function setUp() public {
        aggregatorOracle = new AggregatorOracle();

        // Add a mock oracle
        oracle = new MockProvider();
        oracle.givenQueryReturnResponse(
            abi.encodePacked(Oracle.value.selector),
            MockProvider.ReturnData({
                success: true,
                data: abi.encode(int256(100 * 10**18), true)
            }),
            false
        );
        oracle.givenQueryReturnResponse(
            abi.encodePacked(Oracle.update.selector),
            MockProvider.ReturnData({success: true, data: ""}),
            true
        );
        oracle.givenSelectorReturnResponse(
            Guarded.canCall.selector,
            MockProvider.ReturnData({success: true, data: abi.encode(true)}),
            false
        );

        aggregatorOracle.oracleAdd(address(oracle));
    }

    function test_Deploy() public {
        assertTrue(address(aggregatorOracle) != address(0));
    }

    function test_ReturnsNumberOfOracles() public {
        assertEq(aggregatorOracle.oracleCount(), 1);
    }

    function test_AddOracle() public {
        // Create a mock oracle
        MockProvider newOracle = new MockProvider();
        newOracle.givenSelectorReturnResponse(
            Guarded.canCall.selector,
            MockProvider.ReturnData({success: true, data: abi.encode(true)}),
            false
        );

        // Add the oracle
        aggregatorOracle.oracleAdd(address(newOracle));
    }

    function testFail_AddOracle_ShouldNotAllowDuplicates() public {
        // Create a couple of oracles
        MockProvider oracle1 = new MockProvider();

        // Add the oracle
        aggregatorOracle.oracleAdd(address(oracle1));
        aggregatorOracle.oracleAdd(address(oracle1));
    }

    function test_AddOracle_OnlyAuthorizedUserShouldBeAbleToAdd() public {
        Caller user = new Caller();

        // Create an oracle
        MockProvider oracle1 = new MockProvider();

        oracle1.givenQueryReturnResponse(
            abi.encodePacked(Oracle.update.selector),
            MockProvider.ReturnData({success: true, data: ""}),
            false
        );

        // Add the oracle
        (bool ok, ) = user.externalCall(
            address(aggregatorOracle),
            abi.encodeWithSelector(
                aggregatorOracle.oracleAdd.selector,
                address(oracle1)
            )
        );
        assertTrue(
            ok == false,
            "Only authorized users should be able to add oracles"
        );
    }

    function test_CheckExistenceOfOracle() public {
        // Oracle exists
        assertTrue(aggregatorOracle.oracleExists(address(oracle)));

        // Create an oracle that does not exist
        MockProvider oracle1 = new MockProvider();

        // Check the existence of the oracle
        assertTrue(aggregatorOracle.oracleExists(address(oracle1)) == false);
    }

    function test_RemoveOracle_DeletesOracle() public {
        // Remove the oracle
        aggregatorOracle.oracleRemove(address(oracle));

        // Make sure the oracle is not part of the list anymore
        assertTrue(aggregatorOracle.oracleExists(address(oracle)) == false);
    }

    function testFail_RemoveOracle_ShouldFailIfOracleDoesNotExist() public {
        // Create a couple of oracles
        MockProvider oracle1 = new MockProvider();

        // Remove the oracle
        aggregatorOracle.oracleRemove(address(oracle1));
    }

    function test_RemoveOracle_OnlyAuthorizedUserShouldBeAbleToRemove() public {
        // Create a user without permissions
        Caller user = new Caller();

        // Remove the oracle
        (bool ok, ) = user.externalCall(
            address(aggregatorOracle),
            abi.encodeWithSelector(
                aggregatorOracle.oracleRemove.selector,
                address(oracle)
            )
        );
        assertTrue(
            ok == false,
            "Only authorized users should be able to remove oracles"
        );
    }

    function testFail_RemoveOracle_PossibleIf_MinimumRequiredNumberOfValidValues_CanStillBeMet()
        public
    {
        // Set minimum number of required values to match the number of oracles
        aggregatorOracle.setParam(
            "requiredValidValues",
            aggregatorOracle.oracleCount()
        );

        // Removing 1 oracle should fail
        aggregatorOracle.oracleRemove(address(oracle));
    }

    function test_TriggerUpdate_ShouldCallOracle() public {
        // Trigger the update
        aggregatorOracle.update();

        // Check if the oracle's `update()` was called
        MockProvider.CallData memory cd1 = oracle.getCallData(0);
        assertEq(cd1.caller, address(aggregatorOracle));
        assertEq(cd1.functionSelector, Oracle.update.selector);

        // Can't check if `value()` was called because it's a view function
        // and view functions are called with STATICCALL that do not allow state change
    }

    function test_GetAggregatedValue_WillReturnAverage() public {
        // Remove existing oracle
        aggregatorOracle.oracleRemove(address(oracle));

        // Add oracle1
        MockProvider oracle1 = new MockProvider();
        oracle1.givenQueryReturnResponse(
            abi.encodePacked(Oracle.value.selector),
            MockProvider.ReturnData({
                success: true,
                data: abi.encode(int256(100 * 10**18), true)
            }),
            false
        );
        oracle1.givenQueryReturnResponse(
            abi.encodePacked(Oracle.update.selector),
            MockProvider.ReturnData({success: true, data: ""}),
            true
        );
        oracle1.givenSelectorReturnResponse(
            Guarded.canCall.selector,
            MockProvider.ReturnData({success: true, data: abi.encode(true)}),
            false
        );
        aggregatorOracle.oracleAdd(address(oracle1));

        // Add oracle2
        MockProvider oracle2 = new MockProvider();
        oracle2.givenQueryReturnResponse(
            abi.encodePacked(Oracle.value.selector),
            MockProvider.ReturnData({
                success: true,
                data: abi.encode(int256(300 * 10**18), true)
            }),
            false
        );
        oracle2.givenQueryReturnResponse(
            abi.encodePacked(Oracle.update.selector),
            MockProvider.ReturnData({success: true, data: ""}),
            true
        );
        oracle2.givenSelectorReturnResponse(
            Guarded.canCall.selector,
            MockProvider.ReturnData({success: true, data: abi.encode(true)}),
            false
        );
        aggregatorOracle.oracleAdd(address(oracle2));

        // Trigger the update
        aggregatorOracle.update();

        // Get the aggregated value
        (int256 value, bool valid) = aggregatorOracle.value();

        // Check the return value
        assertEq(value, int256(200 * 10**18));
        assertTrue(valid);
    }

    function test_Update_WithoutOracles_ReturnsZeroAndInvalid() public {
        // Remove existing oracle
        aggregatorOracle.oracleRemove(address(oracle));

        // Trigger the update
        aggregatorOracle.update();

        // Get the aggregated value
        (int256 value, bool valid) = aggregatorOracle.value();

        // Check the return value
        assertEq(value, int256(0));
        assertTrue(valid == false);
    }

    function test_Paused_Stops_ReturnValue() public {
        // Pause aggregator
        aggregatorOracle.pause();

        // Create user
        Caller user = new Caller();

        // Should fail trying to get value
        bool success;
        (success, ) = user.externalCall(
            address(aggregatorOracle),
            abi.encodeWithSelector(aggregatorOracle.value.selector)
        );

        assertTrue(success == false, "value() should fail when paused");
    }

    function test_Paused_DoesNotStop_Update() public {
        // Pause aggregator
        aggregatorOracle.pause();

        // Create user
        Caller user = new Caller();

        aggregatorOracle.allowCaller(aggregatorOracle.ANY_SIG(), address(user));

        // Should fail trying to get value
        bool success;
        (success, ) = user.externalCall(
            address(aggregatorOracle),
            abi.encodeWithSelector(aggregatorOracle.update.selector)
        );

        assertTrue(success, "update() should not fail when paused");
    }

    function test_AggregatorOracle_CanUseAnother_AggregatorOracle_AsAnOracle()
        public
    {
        // Create a new aggregator
        AggregatorOracle localAggregatorOracle = new AggregatorOracle();

        // Create a new oracle
        MockProvider localOracle = new MockProvider();
        localOracle.givenQueryReturnResponse(
            abi.encodePacked(Oracle.value.selector),
            MockProvider.ReturnData({
                success: true,
                data: abi.encode(int256(300 * 10**18), true)
            }),
            false
        );
        localOracle.givenQueryReturnResponse(
            abi.encodePacked(Oracle.update.selector),
            MockProvider.ReturnData({success: true, data: ""}),
            true
        );
        localOracle.givenSelectorReturnResponse(
            Guarded.canCall.selector,
            MockProvider.ReturnData({success: true, data: abi.encode(true)}),
            false
        );

        // Add the new oracle to the new aggregator
        localAggregatorOracle.oracleAdd(address(localOracle));
        localAggregatorOracle.update();

        // Whitelist the aggregator
        localAggregatorOracle.allowCaller(
            localAggregatorOracle.ANY_SIG(),
            address(aggregatorOracle)
        );
        // Add the local aggregator to the aggregator (as an oracle)
        aggregatorOracle.oracleAdd(address(localAggregatorOracle));

        aggregatorOracle.update();

        (int256 value, bool valid) = aggregatorOracle.value();
        assertEq(value, int256(200 * 10**18));
        assertTrue(valid);
    }

    function test_Update_DoesNotFail_IfOracleFails() public {
        // Create a failing oracle
        MockProvider oracle1 = new MockProvider();
        // update() fails
        oracle1.givenQueryReturnResponse(
            abi.encodePacked(Oracle.update.selector),
            MockProvider.ReturnData({success: false, data: ""}),
            true
        );

        oracle1.givenQueryReturnResponse(
            abi.encodePacked(Oracle.value.selector),
            MockProvider.ReturnData({
                success: false,
                data: abi.encode(int256(100 * 10**18), true)
            }),
            false
        );
        oracle1.givenSelectorReturnResponse(
            Guarded.canCall.selector,
            MockProvider.ReturnData({success: true, data: abi.encode(true)}),
            false
        );

        // Add the oracle
        aggregatorOracle.oracleAdd(address(oracle1));

        // Trigger the update
        // The call should not fail
        aggregatorOracle.update();
    }

    function test_Update_IgnoresInvalidValues() public {
        // Create a failing oracle
        MockProvider oracle1 = new MockProvider();
        // update() succeeds
        oracle1.givenQueryReturnResponse(
            abi.encodePacked(Oracle.update.selector),
            MockProvider.ReturnData({success: true, data: ""}),
            true
        );
        oracle1.givenQueryReturnResponse(
            abi.encodePacked(Oracle.value.selector),
            MockProvider.ReturnData({
                success: false,
                data: abi.encode(int256(300 * 10**18), true)
            }),
            false
        );
        oracle1.givenSelectorReturnResponse(
            Guarded.canCall.selector,
            MockProvider.ReturnData({success: true, data: abi.encode(true)}),
            false
        );

        // Add the failing oracle
        aggregatorOracle.oracleAdd(address(oracle1));

        // Trigger the update
        aggregatorOracle.update();

        // Get the aggregated value
        int256 value;
        (value, ) = aggregatorOracle.value();

        // Only the value from the non-failing Oracle is aggregated
        assertEq(value, 100 * 10**18);
    }

    function test_CanSetParam_requiredValidValues() public {
        // Set the minimum required valid values
        aggregatorOracle.setParam("requiredValidValues", 1);

        // Check the minimum required valid values
        assertEq(aggregatorOracle.requiredValidValues(), 1);
    }

    function testFail_ShouldNotBeAbleToSet_InvalidParam() public {
        aggregatorOracle.setParam("invalidParam", 1);
    }

    function test_NonAuthorizedUser_ShouldNotBeAbleTo_SetRequiredValidValues()
        public
    {
        // Create user
        // Do not grant AuthorizedUser to user
        Caller user = new Caller();

        bool success;
        (success, ) = user.externalCall(
            address(aggregatorOracle),
            abi.encodeWithSelector(
                aggregatorOracle.setParam.selector,
                "requiredValidValues",
                1
            )
        );

        assertTrue(
            success == false,
            "Non-AuthorizedUser should not be able to call setParam()"
        );
    }

    function test_AuthorizedUser_ShouldBeAbleTo_SetRequiredValidValues()
        public
    {
        // Create user
        Caller user = new Caller();

        aggregatorOracle.allowCaller(
            aggregatorOracle.setParam.selector,
            address(user)
        );

        bool success;
        (success, ) = user.externalCall(
            address(aggregatorOracle),
            abi.encodeWithSelector(
                aggregatorOracle.setParam.selector,
                bytes32("requiredValidValues"),
                1
            )
        );

        assertTrue(
            success,
            "Authorized user should be able to call setParam()"
        );
    }

    function testFail_ShouldNot_SetRequiredValidValues_HigherThanOracleCount()
        public
    {
        // Set the minimum required valid values to (number of oracles + 1)
        aggregatorOracle.setParam(
            "requiredValidValues",
            aggregatorOracle.oracleCount() + 1
        );
    }

    function test_Aggregator_ReturnsInvalid_IfMinimumNumberOfValidValuesIsNotMet()
        public
    {
        // Create an oracle that returns an invalid value
        MockProvider oracle1 = new MockProvider();
        oracle1.givenQueryReturnResponse(
            abi.encodePacked(Oracle.update.selector),
            MockProvider.ReturnData({success: true, data: ""}),
            true
        );
        // value() returns invalid value
        oracle1.givenQueryReturnResponse(
            abi.encodePacked(Oracle.value.selector),
            MockProvider.ReturnData({
                success: true,
                data: abi.encode(int256(300 * 10**18), false)
            }),
            false
        );
        oracle1.givenSelectorReturnResponse(
            Guarded.canCall.selector,
            MockProvider.ReturnData({success: true, data: abi.encode(true)}),
            false
        );

        // Add the invalid value oracle
        aggregatorOracle.oracleAdd(address(oracle1));

        // Set the minimum number of valid values to 2
        aggregatorOracle.setParam("requiredValidValues", 2);

        // Trigger the update
        // There's only one oracle set in the aggregator
        aggregatorOracle.update();

        // Get the aggregated value
        (, bool valid) = aggregatorOracle.value();

        // Check the return value
        assertTrue(valid == false, "Minimum number of valid values not met");
    }

    function test_setParam_requiredValidValues_changesTheParameter() public {
        aggregatorOracle.setParam("requiredValidValues", 1);

        assertEq(aggregatorOracle.requiredValidValues(), 1);
    }
}
