// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import "ds-test/test.sol";

import {Hevm} from "src/test/utils/Hevm.sol";
import {MockProvider} from "@cleanunicorn/mockprovider/src/MockProvider.sol";
import {Caller} from "src/test/utils/Caller.sol";

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
        aggregatorOracle.oracleAdd(address(oracle));
    }

    function test_deploy() public {
        assertTrue(address(aggregatorOracle) != address(0));
    }

    function test_returnsNumberOfOracles() public {
        assertEq(aggregatorOracle.oracleCount(), 1);
    }

    function test_addOracle() public {
        // Create a new address since the oracle is not checked for validity in anyway
        address newOracle = address(0x1);

        // Add the oracle
        aggregatorOracle.oracleAdd(newOracle);
    }

    function testFail_addOracle_shouldNotAllowDuplicates() public {
        // Create a couple of oracles
        MockProvider oracle1 = new MockProvider();

        // Add the oracle
        aggregatorOracle.oracleAdd(address(oracle1));
        aggregatorOracle.oracleAdd(address(oracle1));
    }

    function test_addOracle_onlyAuthorizedUserShouldBeAbleToAdd() public {
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

    function test_checkExistenceOfOracle() public {
        // Oracle exists
        assertTrue(aggregatorOracle.oracleExists(address(oracle)));

        // Create an oracle that does not exist
        MockProvider oracle1 = new MockProvider();

        // Check the existence of the oracle
        assertTrue(aggregatorOracle.oracleExists(address(oracle1)) == false);
    }

    function test_removeOracle_deletesOracle() public {
        // Remove the oracle
        aggregatorOracle.oracleRemove(address(oracle));

        // Make sure the oracle is not part of the list anymore
        assertTrue(aggregatorOracle.oracleExists(address(oracle)) == false);
    }

    function testFail_removeOracle_shouldFailIfOracleDoesNotExist() public {
        // Create a couple of oracles
        MockProvider oracle1 = new MockProvider();

        // Remove the oracle
        aggregatorOracle.oracleRemove(address(oracle1));
    }

    function test_removeOracle_onlyAuthorizedUserShouldBeAbleToRemove() public {
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

    function testFail_removeOracle_possibleIf_minimumRequiredNumberOfValidValues_canStillBeMet()
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

    function test_oracleAt_returnsCorrectAddress() public {
        // Create a new address since the oracle is not checked for validity in anyway
        address newOracle = address(0x1);

        // Cache the current oracle count
        uint256 oracleCount = aggregatorOracle.oracleCount();

        // Add the oracle
        aggregatorOracle.oracleAdd(newOracle);

        assertEq(
            newOracle,
            aggregatorOracle.oracleAt(oracleCount),
            "Invalid oracleAt address"
        );
    }

    function testFail_oracleAt_shouldFailWithInvalidIndex() public {
        uint256 outOfBoundsIndex = aggregatorOracle.oracleCount();
        // Try to access oracle
        aggregatorOracle.oracleAt(outOfBoundsIndex);
    }

    function test_triggerUpdate_shouldCallOracle() public {
        // Trigger the update
        aggregatorOracle.update();

        // Check if the oracle's `update()` was called
        MockProvider.CallData memory cd1 = oracle.getCallData(0);
        assertEq(cd1.caller, address(aggregatorOracle));
        assertEq(cd1.functionSelector, Oracle.update.selector);

        // Can't check if `value()` was called because it's a view function
        // and view functions are called with STATICCALL that do not allow state change
    }

    function test_getAggregatedValue_willReturnAverage() public {
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
        aggregatorOracle.oracleAdd(address(oracle2));

        // Trigger the update
        aggregatorOracle.update();

        // Get the aggregated value
        (int256 value, bool valid) = aggregatorOracle.value();

        // Check the return value
        assertEq(value, int256(200 * 10**18));
        assertTrue(valid);
    }

    function test_update_withoutOracles_returnsZeroAndInvalid() public {
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

    function test_paused_stops_returnValue() public {
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

    function test_paused_doesNotStop_update() public {
        // Pause aggregator
        aggregatorOracle.pause();

        // Create user
        Caller user = new Caller();

        // Should fail trying to get value
        bool success;
        (success, ) = user.externalCall(
            address(aggregatorOracle),
            abi.encodeWithSelector(aggregatorOracle.update.selector)
        );

        assertTrue(success, "update() should not fail when paused");
    }

    function test_aggregatorOracle_canUseAnother_aggregatorOracle_asAnOracle()
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

        // Add the new oracle to the new aggregator
        localAggregatorOracle.oracleAdd(address(localOracle));
        localAggregatorOracle.update();

        // Add the local aggregator to the aggregator (as an oracle)
        aggregatorOracle.oracleAdd(address(localAggregatorOracle));

        aggregatorOracle.update();

        (int256 value, bool valid) = aggregatorOracle.value();
        assertEq(value, int256(200 * 10**18));
        assertTrue(valid);
    }

    function test_update_doesNotFail_ifOracleFails() public {
        // Create a failing oracle
        MockProvider oracle1 = new MockProvider();
        // update() fails
        oracle1.givenQueryReturnResponse(
            abi.encodePacked(Oracle.update.selector),
            MockProvider.ReturnData({success: false, data: ""}),
            true
        );
        // value() fails
        oracle1.givenQueryReturnResponse(
            abi.encodePacked(Oracle.value.selector),
            MockProvider.ReturnData({
                success: false,
                data: abi.encode(int256(100 * 10**18), true)
            }),
            false
        );

        // Add the oracle
        aggregatorOracle.oracleAdd(address(oracle1));

        // Trigger the update
        // The call should not fail
        aggregatorOracle.update();
    }

    function test_update_ignoresInvalidValues() public {
        // Create a failing oracle
        MockProvider oracle1 = new MockProvider();
        // update() succeeds
        oracle1.givenQueryReturnResponse(
            abi.encodePacked(Oracle.update.selector),
            MockProvider.ReturnData({success: true, data: ""}),
            true
        );
        // value() fails
        oracle1.givenQueryReturnResponse(
            abi.encodePacked(Oracle.value.selector),
            MockProvider.ReturnData({
                success: false,
                data: abi.encode(int256(300 * 10**18), true)
            }),
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

    function test_canSetParam_requiredValidValues() public {
        // Set the minimum required valid values
        aggregatorOracle.setParam("requiredValidValues", 1);

        // Check the minimum required valid values
        assertEq(aggregatorOracle.requiredValidValues(), 1);
    }

    function testFail_shouldNotBeAbleToSet_invalidParam() public {
        aggregatorOracle.setParam("invalidParam", 1);
    }

    function test_nonAuthorizedUser_shouldNotBeAbleTo_setRequiredValidValues()
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

    function test_authorizedUser_shouldBeAbleTo_setRequiredValidValues()
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

    function testFail_shouldNot_setRequiredValidValues_higherThanOracleCount()
        public
    {
        // Set the minimum required valid values to (number of oracles + 1)
        aggregatorOracle.setParam(
            "requiredValidValues",
            aggregatorOracle.oracleCount() + 1
        );
    }

    function test_aggregator_returnsInvalid_ifMinimumNumberOfValidValuesIsNotMet()
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
