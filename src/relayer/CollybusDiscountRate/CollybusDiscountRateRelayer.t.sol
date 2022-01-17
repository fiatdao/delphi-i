// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import {Hevm} from "src/test/utils/Hevm.sol";
import {DSTest} from "lib/ds-test/src/test.sol";
import {MockProvider} from "src/test/utils/MockProvider.sol";
import {Caller} from "src/test/utils/Caller.sol";

import {ICollybus} from "src/relayer/ICollybus.sol";
import {CollybusDiscountRateRelayer} from "./CollybusDiscountRateRelayer.sol";
import {IOracle} from "src/oracle/IOracle.sol";
import {IValueProvider} from "src/valueprovider/IValueProvider.sol";

contract TestCollybus is ICollybus {
    mapping(uint256 => uint256) public rateForTokenId;

    function updateDiscountRate(uint256 tokenId, uint256 rate)
        external
        override(ICollybus)
    {
        rateForTokenId[tokenId] = rate;
    }
}

contract CollybusDiscountRateRelayerTest is DSTest {
    Hevm internal hevm = Hevm(DSTest.HEVM_ADDRESS);
    CollybusDiscountRateRelayer internal cdrr;
    TestCollybus internal collybus;

    MockProvider internal oracle1;

    uint256 internal oracleTimeUpdateWindow = 100; // seconds
    uint256 internal oracleMaxValidTime = 300;
    int256 internal oracleAlpha = 2 * 10**17; // 0.2

    uint256 internal mockTokenId1 = 1;
    uint256 internal mockTokenId1MinThreshold = 1;

    function setUp() public {
        collybus = new TestCollybus();
        cdrr = new CollybusDiscountRateRelayer(address(collybus));

        oracle1 = new MockProvider();

        // Set the value returned by Value Provider.
        oracle1.givenQueryReturnResponse(
            abi.encodePacked(IOracle.value.selector),
            MockProvider.ReturnData({
                success: true,
                data: abi.encode(int256(100 * 10**18), true)
            }),
            false
        );

        // Add oracle with rate id
        cdrr.oracleAdd(
            address(oracle1),
            mockTokenId1,
            mockTokenId1MinThreshold
        );
        hevm.warp(oracleTimeUpdateWindow);
    }

    function test_Deploy() public {
        assertTrue(
            address(cdrr) != address(0),
            "CollybusDiscountRateRelayer should be deployed"
        );
    }

    function test_CheckExistenceOfOracle() public {
        // Check that oracle was added
        assertTrue(
            cdrr.oracleExists(address(oracle1)),
            "Oracle should be added"
        );
    }

    function test_ReturnNumberOfOracles() public {
        // Check the number of existing oracles
        assertTrue(
            cdrr.oracleCount() == 1,
            "CollybusDiscountRateRelayer should contain 1 oracle."
        );
    }

    function test_AddOracle() public {
        // Create a new address since the oracle is not checked for validity anyway
        address newOracle = address(0x1);
        uint256 mockTokenId2 = mockTokenId1 + 1;

        // Add the oracle and use the same threshold as oracle 1
        cdrr.oracleAdd(newOracle, mockTokenId2, mockTokenId1MinThreshold);
    }

    function testFail_AddOracle_ShouldNotAllowDuplicateOracles() public {
        // Attempt to add the same oracle again
        cdrr.oracleAdd(
            address(oracle1),
            mockTokenId1,
            mockTokenId1MinThreshold
        );
    }

    function testFail_AddOracle_ShouldNotAllowDuplicateTokenIds() public {
        // We can use any address, the oracle will not be interrogated on add.
        address newOracle = address(0x1);
        // Add a new oracle that has the same token id as the previously added oracle.
        cdrr.oracleAdd(
            address(newOracle),
            mockTokenId1,
            mockTokenId1MinThreshold
        );
    }

    function test_AddOracle_OnlyAuthorizedUserShouldBeAbleToAdd() public {
        Caller user = new Caller();

        address newOracle = address(0x1);
        uint256 mockTokenId2 = mockTokenId1 + 1;
        uint256 mockTokenId2MinThreshold = mockTokenId1MinThreshold;
        // Add the oracle
        (bool ok, ) = user.externalCall(
            address(cdrr),
            abi.encodeWithSelector(
                cdrr.oracleAdd.selector,
                newOracle,
                mockTokenId2,
                mockTokenId2MinThreshold
            )
        );
        assertTrue(
            ok == false,
            "Only authorized users should be able to add oracles"
        );
    }

    function test_RemoveOracle_DeletesOracle() public {
        // Remove the only oracle.
        cdrr.oracleRemove(address(oracle1));

        // Relayer should be empty
        assertTrue(
            cdrr.oracleCount() == 0,
            "CollybusDiscountRateRelayer should be empty"
        );
    }

    function testFail_RemoveOracle_ShouldFailIfOracleDoesNotExist() public {
        address newOracle = address(0x1);

        // Attempt to remove oracle that does not exist.
        cdrr.oracleRemove(newOracle);
    }

    function test_RemoveOracle_OnlyAuthorizedUserShouldBeAbleToRemove() public {
        Caller user = new Caller();

        // Add the oracle
        (bool ok, ) = user.externalCall(
            address(cdrr),
            abi.encodeWithSelector(cdrr.oracleRemove.selector, address(oracle1))
        );
        assertTrue(
            ok == false,
            "Only authorized users should be able to add oracles"
        );
    }

    function test_checkCalls_returnsTrueWhenUpdateNeeded() public {
        bool mustUpdate = cdrr.check();
        assertTrue(mustUpdate);
    }

    function test_CheckCallsUpdate_OnlyOnFirstUpdatableOracle() public {
        MockProvider oracle2 = new MockProvider();
        // Set the value returned by Value Provider.
        oracle2.givenQueryReturnResponse(
            abi.encodePacked(IOracle.value.selector),
            MockProvider.ReturnData({
                success: true,
                data: abi.encode(int256(100 * 10**18), true)
            }),
            false
        );

        uint256 mockTokenId2 = mockTokenId1 + 1;
        uint256 mockTokenId2MinThreshold = mockTokenId1MinThreshold;
        // Add oracle with rate id
        cdrr.oracleAdd(
            address(oracle2),
            mockTokenId2,
            mockTokenId2MinThreshold
        );
        hevm.warp(oracleTimeUpdateWindow);

        // Check will search for at least one updatable oracle, which in our case is the first one in the list
        // therefore, the first oracle will be updated but the second will not.
        cdrr.check();

        //update should be the first called function
        MockProvider.CallData memory cd1 = oracle1.getCallData(0);
        assertTrue(cd1.functionSelector == IOracle.update.selector);

        //no function calls for our second oracle
        MockProvider.CallData memory cd2 = oracle2.getCallData(0);
        assertTrue(cd2.functionSelector == bytes4(0));
    }

    function test_CheckCalls_ReturnsFalseAfterExecute() public {
        bool checkBeforeUpdate = cdrr.check();
        assertTrue(checkBeforeUpdate);

        cdrr.execute();

        bool checkAfterUpdate = cdrr.check();
        assertTrue(checkAfterUpdate == false);
    }

    function test_ExecuteCalls_UpdateOnAllOracles() public {
        MockProvider oracle2 = new MockProvider();
        // Set the value returned by Value Provider.
        oracle2.givenQueryReturnResponse(
            abi.encodePacked(IOracle.value.selector),
            MockProvider.ReturnData({
                success: true,
                data: abi.encode(int256(100 * 10**18), true)
            }),
            false
        );

        uint256 mockTokenId2 = mockTokenId1 + 1;
        uint256 mockTokenId2MinThreshold = mockTokenId1MinThreshold;
        // Add oracle with rate id
        cdrr.oracleAdd(
            address(oracle2),
            mockTokenId2,
            mockTokenId2MinThreshold
        );
        hevm.warp(oracleTimeUpdateWindow);

        // Execute must call update on all oracles before pushing the values to Collybus.
        cdrr.check();
        cdrr.execute();

        // Update was called for both oracles
        MockProvider.CallData memory cd1 = oracle1.getCallData(0);
        assertTrue(cd1.functionSelector == IOracle.update.selector);

        MockProvider.CallData memory cd2 = oracle2.getCallData(0);
        assertTrue(cd2.functionSelector == IOracle.update.selector);
    }

    function test_Execute_UpdatesRatesInCollybus() public {
        MockProvider oracle2 = new MockProvider();

        // Set the value returned by Value Provider.
        oracle2.givenQueryReturnResponse(
            abi.encodePacked(IOracle.value.selector),
            MockProvider.ReturnData({
                success: true,
                data: abi.encode(int256(10 * 10**18), true)
            }),
            false
        );

        uint256 mockTokenId2 = mockTokenId1 + 1;
        uint256 mockTokenId2MinThreshold = mockTokenId1MinThreshold;
        // Add oracle with rate id.
        cdrr.oracleAdd(
            address(oracle2),
            mockTokenId2,
            mockTokenId2MinThreshold
        );
        hevm.warp(oracleTimeUpdateWindow);

        // Execute must call update on all oracles before pushing the values to Collybus.
        // Check should trigger an update because the value delta is bigger than the minimum for both oracles.
        bool mustUpdate = cdrr.check();
        assertTrue(mustUpdate);

        cdrr.execute();

        assertTrue(
            collybus.rateForTokenId(mockTokenId1) == uint256(100 * 10**18)
        );
        assertTrue(
            collybus.rateForTokenId(mockTokenId2) == uint256(10 * 10**18)
        );
    }

    function test_Execute_DoesNotUpdatesRatesInCollybusWhenDeltaIsBelowThreshold()
        public
    {
        MockProvider oracle2 = new MockProvider();

        int256 oracle2InitialValue = int256(10 * 10**18);
        // Set the value returned by Value Provider.
        oracle2.givenQueryReturnResponse(
            abi.encodePacked(IOracle.value.selector),
            MockProvider.ReturnData({
                success: true,
                data: abi.encode(oracle2InitialValue, true)
            }),
            false
        );

        uint256 mockTokenId2 = mockTokenId1 + 1;
        uint256 mockTokenId2MinThreshold = 1 * 10**18;
        // Add oracle with rate id
        cdrr.oracleAdd(
            address(oracle2),
            mockTokenId2,
            mockTokenId2MinThreshold
        );
        hevm.warp(oracleTimeUpdateWindow);

        // Execute must call update on all oracles before pushing the values to Collybus.
        cdrr.check();
        cdrr.execute();

        int256 oracle1NewValue = int256(10 * 10**18);
        oracle1.givenQueryReturnResponse(
            abi.encodePacked(IOracle.value.selector),
            MockProvider.ReturnData({
                success: true,
                data: abi.encode(oracle1NewValue, true)
            }),
            false
        );

        // Make the second value returned by the oracle to be just lower than the minimum threshold
        int256 oracle2NewValue = oracle2InitialValue +
            int256(mockTokenId2MinThreshold) -
            1;

        oracle2.givenQueryReturnResponse(
            abi.encodePacked(IOracle.value.selector),
            MockProvider.ReturnData({
                success: true,
                data: abi.encode(oracle2NewValue, true)
            }),
            false
        );

        hevm.warp(oracleTimeUpdateWindow);

        cdrr.execute();

        // Rate 1 from oracle 1 will be updated with the new value because the delta was bigger than the minimum threshold
        assertTrue(
            collybus.rateForTokenId(mockTokenId1) == uint256(oracle1NewValue)
        );

        // Rate 2 from oracle 2 will NOT be updated because the delta is smaller than the threshold.
        assertTrue(
            collybus.rateForTokenId(mockTokenId2) ==
                uint256(oracle2InitialValue)
        );
    }
}
