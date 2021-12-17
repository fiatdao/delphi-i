// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import "ds-test/test.sol";

import {Hevm} from "./test/utils/Hevm.sol";
import {MockProvider} from "./test/utils/MockProvider.sol";
import {Caller} from "./test/utils/Caller.sol";

import {Oracle} from "./Oracle.sol";
import {AggregatorOracle} from "./AggregatorOracle.sol";

contract OracleTest is DSTest {
    Hevm hevm = Hevm(DSTest.HEVM_ADDRESS);

    AggregatorOracle aggregatorOracle;
    MockProvider oracle;

    function setUp() public {
        aggregatorOracle = new AggregatorOracle();

        // Add a mock oracle
        oracle = new MockProvider();
        oracle.givenQueryReturnResponse(
            abi.encodePacked(Oracle.update.selector),
            MockProvider.ReturnData({
                success: true,
                data: abi.encode(int256(100 * 10**18), true)
            }),
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
            abi.encode(),
            MockProvider.ReturnData({
                success: true,
                data: abi.encode(int256(100 * 10**18))
            }),
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

        assertTrue(aggregatorOracle.oracleExists(address(oracle)) == false);
    }

    function testFail_RemoveOracle_ShouldFailIfOracleDoesNotExist() public {
        // Create a couple of oracles
        MockProvider oracle1 = new MockProvider();

        // Remove the oracle
        aggregatorOracle.oracleRemove(address(oracle1));
    }

    function test_RemoveOracle_OnlyRootShouldBeAbleToRemove() public {
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
        aggregatorOracle.updateAll();

        // Check the oracle was called
        MockProvider.CallData memory cd = oracle.getCallData(0);
        assertEq(cd.caller, address(aggregatorOracle));
        assertEq(cd.functionSelector, Oracle.update.selector);
    }

    function test_TriggerUpdate_ReturnsValue() public {
        // Trigger the update
        (int256 value, bool valid) = aggregatorOracle.updateAll();

        // Check the return value
        assertEq(value, int256(100 * 10**18));
        assertTrue(valid);
    }

    function test_GetAggregatedValue_WillReturnAverage() public {
        // Remove existing oracle
        aggregatorOracle.oracleRemove(address(oracle));

        // Add oracle1
        MockProvider oracle1 = new MockProvider();
        oracle1.givenQueryReturnResponse(
            abi.encodePacked(Oracle.update.selector),
            MockProvider.ReturnData({
                success: true,
                data: abi.encode(int256(100 * 10**18), true)
            }),
            true
        );
        aggregatorOracle.oracleAdd(address(oracle1));

        // Add oracle2
        MockProvider oracle2 = new MockProvider();
        oracle2.givenQueryReturnResponse(
            abi.encodePacked(Oracle.update.selector),
            MockProvider.ReturnData({
                success: true,
                data: abi.encode(int256(300 * 10**18), true)
            }),
            true
        );
        aggregatorOracle.oracleAdd(address(oracle2));

        // Trigger the update
        aggregatorOracle.updateAll();

        // Get the aggregated value
        (int256 value, bool valid) = aggregatorOracle.value();

        // Check the return value
        assertEq(value, int256(200 * 10**18));
        assertTrue(valid);
    }
}
