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

        oracle = new MockProvider();
        aggregatorOracle.addOracle(address(oracle));
    }

    function test_deploy() public {
        assertTrue(address(aggregatorOracle) != address(0));
    }

    function test_ReturnsNumberOfOracles() public {
        assertEq(aggregatorOracle.oracleCount(), 1);
    } 

    function test_AddOracle_ReturnsIndex() public {
        // Create a new oracle
        MockProvider localOracle = new MockProvider();
        
        // Add the oracle
        aggregatorOracle.addOracle(address(localOracle));
    }

    function testFail_AddOracle_ShouldNotAllowDuplicates() public {
        // Create a couple of oracles
        MockProvider oracle1 = new MockProvider();
        
        // Add the oracle
        aggregatorOracle.addOracle(address(oracle1));
        aggregatorOracle.addOracle(address(oracle1));
    }

    function testFail_AddOracle_OnlyPermissionedUserShouldBeAbleToAdd() public {
        Caller user = new Caller();

        // Create a couple of oracles
        MockProvider oracle1 = new MockProvider();
        
        // Add the oracle
        user.externalCall(
            address(aggregatorOracle), 
            abi.encodeWithSelector(aggregatorOracle.addOracle.selector, address(oracle1))
        );
        // aggregatorOracle.addOracle(address(oracle1));
    }

    // function test_RemoveOracle_DeletesOracle() public {
    //     // Remove the oracle
    //     aggregatorOracle.removeOracle(address(oracle));

    //     // Make sure the oracle is not in the list
    //     // aggregatorOracle.
    // }

}