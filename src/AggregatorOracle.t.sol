// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import "ds-test/test.sol";

import {Hevm} from "./test/utils/Hevm.sol";
import {MockProvider} from "./test/utils/MockProvider.sol";
import {Caller} from "./test/utils/Caller.sol";

import {Oracle} from "./Oracle.sol";
import {AggregatorOracle} from "./AggregatorOracle.sol";

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

    function test_Deploy() public {
        assertTrue(address(aggregatorOracle) != address(0));
    }

    function test_ReturnsNumberOfOracles() public {
        assertEq(aggregatorOracle.oracleCount(), 1);
    }

    function test_AddOracle() public {
        // Create a new oracle
        MockProvider localOracle = new MockProvider();
        localOracle.givenQueryReturnResponse(
            abi.encodePacked(Oracle.value.selector),
            MockProvider.ReturnData({
                success: true,
                data: abi.encode(int256(100 * 10**18), true)
            }),
            false
        );
        localOracle.givenQueryReturnResponse(
            abi.encodePacked(Oracle.update.selector),
            MockProvider.ReturnData({success: true, data: ""}),
            true
        );

        // Add the oracle
        aggregatorOracle.oracleAdd(address(localOracle));
    }

    function testFail_AddOracle_ShouldNotAllowDuplicates() public {
        // Create a couple of oracles
        MockProvider oracle1 = new MockProvider();

        // Add the oracle
        aggregatorOracle.oracleAdd(address(oracle1));
        aggregatorOracle.oracleAdd(address(oracle1));
    }

    function test_AddOracle_OnlyRootShouldBeAbleToAdd() public {
        Caller user = new Caller();

        // Create a couple of oracles
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
        assertTrue(ok == false);
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

    function test_RemoveOracle_OnlyRootShouldBeAbleToRemove() public {
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
        assertTrue(ok == false);
    }

    function test_TriggerUpdate_ShouldCallOracle() public {
        // Trigger the update
        aggregatorOracle.update();

        // Check the oracle was called
        MockProvider.CallData memory cd = oracle.getCallData(0);
        assertEq(cd.caller, address(aggregatorOracle));
        assertEq(cd.functionSelector, Oracle.update.selector);
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

    function test_Update_WithoutOracles_ReturnsZero() public {
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

        // Should fail trying to get value
        bool success;
        (success, ) = user.externalCall(
            address(aggregatorOracle),
            abi.encodeWithSelector(aggregatorOracle.update.selector)
        );

        assertTrue(success, "update() should not fail when paused");
    }
}
