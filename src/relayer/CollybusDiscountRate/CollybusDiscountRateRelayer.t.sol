// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import {DSTest} from "lib/ds-test/src/test.sol";
import {MockProvider} from "src/test/utils/MockProvider.sol";

import {ICollybus} from "src/relayer/ICollybus.sol";
import {CollybusDiscountRateRelayer} from "./CollybusDiscountRateRelayer.sol";
import {IOracle} from "src/oracle/IOracle.sol";

contract TestCollybus is ICollybus {
    function updateDiscountRate(uint256 tokenId, int256 rate)
        external
        override(ICollybus)
    {}
}

contract CollybusDiscountRateRelayerTest is DSTest {
    CollybusDiscountRateRelayer internal cdrr;
    TestCollybus internal collybus;

    function setUp() public {
        collybus = new TestCollybus();
        cdrr = new CollybusDiscountRateRelayer(address(collybus));
    }

    function test_deploy() public {
        assertTrue(
            address(cdrr) != address(0),
            "CollybusDiscountRateRelayer should be deployed"
        );
    }

    function test_addOracle_withRateId() public {
        // Create some mock data
        address mockOracle = address(0x123);
        uint256 mockRateId = 0x456;
        uint256 rateMinThreshold = 0;

        // Add oracle with rate id
        cdrr.oracleAdd(mockOracle, mockRateId, rateMinThreshold);

        // Check that oracle was added
        assertTrue(cdrr.oracleExists(mockOracle), "Oracle should be added");
    }

    function test_ReturnNumberOfOracles() public {}

    function testFail_AddOracle_ShouldNotAllowDuplicates() public {}

    function test_AddOracle_OnlyAuthorizedUserShouldBeAbleToAdd() public {}

    function test_CheckExistenceOfOracle() public {}

    function test_RemoveOracle_DeletesOracle() public {}

    function testFail_RemoveOracle_ShouldFailIfOracleDoesNotExist() public {}

    function test_RemoveOracle_OnlyAuthorizedUserShouldBeAbleToRemove()
        public
    {}

    function test_checkCallsUpdate_onAllOracles() public {
        // Create an oracle with an associated rateId
        MockProvider oracle1 = new MockProvider();
        uint256 rateId1 = 0x1;
        uint256 rateMinThreshold1 = 0;

        // Add the oracle
        cdrr.oracleAdd(address(oracle1), rateId1, rateMinThreshold1);

        cdrr.check();

        // Check that the oracle was called correctly
        MockProvider.CallData memory cd = oracle1.getCallData(0);
        assertEq(
            cd.caller,
            address(cdrr),
            "Caller should be CollybusDiscountRateRelayer"
        );
        assertEq(cd.functionSelector, IOracle.update.selector);
        assertEq(
            keccak256(cd.data),
            keccak256(abi.encodeWithSelector(IOracle.update.selector))
        );
        assertEq(cd.value, 0);
    }
}
