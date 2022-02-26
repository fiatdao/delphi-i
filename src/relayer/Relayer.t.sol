// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import {Hevm} from "src/test/utils/Hevm.sol";
import {DSTest} from "lib/ds-test/src/test.sol";
import {MockProvider} from "@cleanunicorn/mockprovider/src/MockProvider.sol";
import {Caller} from "src/test/utils/Caller.sol";

import {ICollybus} from "src/relayer/ICollybus.sol";
import {Relayer} from "src/relayer/Relayer.sol";
import {IRelayer} from "src/relayer/IRelayer.sol";
import {IOracle} from "src/oracle/IOracle.sol";

contract TestCollybus is ICollybus {
    mapping(bytes32 => uint256) public valueForToken;

    function updateDiscountRate(uint256 tokenId, uint256 rate)
        external
        override(ICollybus)
    {
        valueForToken[bytes32(uint256(tokenId))] = rate;
    }

    function updateSpot(address tokenAddress, uint256 spot)
        external
        override(ICollybus)
    {
        valueForToken[bytes32(uint256(uint160(tokenAddress)))] = spot;
    }
}

contract RelayerTest is DSTest {
    Hevm internal hevm = Hevm(DSTest.HEVM_ADDRESS);
    Relayer internal relayer;
    TestCollybus internal collybus;
    IRelayer.RelayerType internal relayerType =
        IRelayer.RelayerType.DiscountRate;

    MockProvider internal oracle1;

    uint256 internal oracleTimeUpdateWindow = 100; // seconds
    uint256 internal oracleMaxValidTime = 300;
    int256 internal oracleAlpha = 2 * 10**17; // 0.2

    bytes32 internal mockTokenId1;
    uint256 internal mockTokenId1MinThreshold = 1;
    int256 internal oracle1InitialValue = 100 * 10**18;

    function setUp() public {
        collybus = new TestCollybus();
        relayer = new Relayer(address(collybus), relayerType);

        oracle1 = new MockProvider();

        mockTokenId1 = bytes32(uint256(1));

        // Set the value returned by the Oracle.
        oracle1.givenQueryReturnResponse(
            abi.encodePacked(IOracle.value.selector),
            MockProvider.ReturnData({
                success: true,
                data: abi.encode(oracle1InitialValue, true)
            }),
            false
        );

        // Add oracle with rate id
        relayer.oracleAdd(
            address(oracle1),
            mockTokenId1,
            mockTokenId1MinThreshold
        );
    }

    function test_deploy() public {
        assertTrue(
            address(relayer) != address(0),
            "Relayer should be deployed"
        );
    }

    function test_check_collybus() public {
        assertEq(relayer.collybus(), address(collybus));
    }

    function test_check_relayerType() public {
        assertTrue(relayer.relayerType() == relayerType, "Invalid relayerType");
    }

    function test_check_oracleData() public {
        Relayer.OracleData memory oracleData = relayer.oraclesData(
            address(oracle1)
        );

        assertTrue(oracleData.exists);
        assertEq(oracleData.lastUpdateValue, 0);
        assertEq(oracleData.tokenId, mockTokenId1);
        assertEq(
            oracleData.minimumPercentageDeltaValue,
            mockTokenId1MinThreshold
        );
    }

    function test_checkExistenceOfOracle() public {
        // Check that oracle was added
        assertTrue(
            relayer.oracleExists(address(oracle1)),
            "Oracle should be added"
        );
    }

    function test_returnNumberOfOracles() public {
        // Check the number of existing oracles
        assertTrue(
            relayer.oracleCount() == 1,
            "CollybusDiscountRateRelayer should contain 1 oracle"
        );
    }

    function test_addOracle() public {
        // Create a new address that differs from the oracle already added
        address newOracle = address(0x1);
        bytes32 mockTokenId2 = bytes32(uint256(mockTokenId1) + 1);

        // Add the oracle for a new token ID.
        relayer.oracleAdd(newOracle, mockTokenId2, mockTokenId1MinThreshold);

        // Check that oracle was added
        assertTrue(relayer.oracleExists(newOracle), "Oracle should be added");

        // Check the number of existing oracles
        assertTrue(
            relayer.oracleCount() == 2,
            "CollybusDiscountRateRelayer should contain 2 oracles"
        );
    }

    function testFail_addOracle_shouldNotAllowDuplicateOracles() public {
        // Attempt to add the same oracle again but use a different token id.
        bytes32 mockTokenId2 = bytes32(uint256(mockTokenId1) + 1);

        relayer.oracleAdd(
            address(oracle1),
            mockTokenId2,
            mockTokenId1MinThreshold
        );
    }

    function testFail_addOracle_shouldNotAllowDuplicateTokenIds() public {
        // We can use any address, the oracle will not be interrogated on add.
        address newOracle = address(0x1);
        // Add a new oracle that has the same token id as the previously added oracle.
        relayer.oracleAdd(
            address(newOracle),
            mockTokenId1,
            mockTokenId1MinThreshold
        );
    }

    function test_addOracle_onlyAuthorizedUserShouldBeAbleToAdd() public {
        Caller user = new Caller();

        address newOracle = address(0x1);
        bytes32 mockTokenId2 = bytes32(uint256(mockTokenId1) + 1);
        uint256 mockTokenId2MinThreshold = mockTokenId1MinThreshold;
        // Add the oracle
        (bool ok, ) = user.externalCall(
            address(relayer),
            abi.encodeWithSelector(
                relayer.oracleAdd.selector,
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

    function test_addOracle_tokenIdMarkedAsUsed() public {
        // Check that the added oracle id is correctly marked as used
        assertTrue(relayer.encodedTokenIds(mockTokenId1),"Token Id not marked as used");
    }

    function test_removeOracle_deletesOracle() public {
        // Remove the only oracle.
        relayer.oracleRemove(address(oracle1));

        // Oracle should not exist
        assertTrue(
            relayer.oracleExists(address(oracle1)) == false,
            "Relayer oracle should be deleted"
        );
    }

    function test_removeOracle_resetsTokenIdUsedFlag() public{
        // Remove the only oracle.
        relayer.oracleRemove(address(oracle1));

        // Token id should be unused
        assertTrue(
            relayer.encodedTokenIds(mockTokenId1) == false,
            "Relayer oracle should be deleted"
        );
    }

    function testFail_removeOracle_shouldFailIfOracleDoesNotExist() public {
        address newOracle = address(0x1);

        // Attempt to remove oracle that does not exist.
        relayer.oracleRemove(newOracle);
    }

    function test_removeOracle_onlyAuthorizedUserShouldBeAbleToRemove() public {
        Caller user = new Caller();

        // Add the oracle
        (bool ok, ) = user.externalCall(
            address(relayer),
            abi.encodeWithSelector(
                relayer.oracleRemove.selector,
                address(oracle1)
            )
        );
        assertTrue(
            ok == false,
            "Only authorized users should be able to add oracles"
        );
    }

    function test_checkCalls_returnsTrueWhenUpdateNeeded() public {
        bool mustUpdate = relayer.check();
        assertTrue(mustUpdate);
    }

    function test_checkCallsUpdate_onlyOnFirstUpdatableOracle() public {
        MockProvider oracle2 = new MockProvider();
        // Set the value returned by the Oracle.
        oracle2.givenQueryReturnResponse(
            abi.encodePacked(IOracle.value.selector),
            MockProvider.ReturnData({
                success: true,
                data: abi.encode(int256(100 * 10**18), true)
            }),
            false
        );

        bytes32 mockTokenId2 = bytes32(uint256(mockTokenId1) + 1);
        uint256 mockTokenId2MinThreshold = mockTokenId1MinThreshold;
        // Add oracle with rate id
        relayer.oracleAdd(
            address(oracle2),
            mockTokenId2,
            mockTokenId2MinThreshold
        );

        // Check will search for at least one updatable oracle, which in our case is the first one in the list
        // therefore, the first oracle will be updated but the second will not
        relayer.check();

        // Update should be the first called function
        MockProvider.CallData memory cd1 = oracle1.getCallData(0);
        assertTrue(cd1.functionSelector == IOracle.update.selector);

        // No function calls for our second oracle
        MockProvider.CallData memory cd2 = oracle2.getCallData(0);
        assertTrue(cd2.functionSelector == bytes4(0));
    }

    function test_check_returnsFalseAfterExecute() public {
        bool checkBeforeUpdate = relayer.check();
        assertTrue(checkBeforeUpdate);

        relayer.execute();

        bool checkAfterUpdate = relayer.check();
        assertTrue(checkAfterUpdate == false);
    }

    function test_executeCalls_updateOnAllOracles() public {
        MockProvider oracle2 = new MockProvider();
        // Set the value returned by the Oracle.
        oracle2.givenQueryReturnResponse(
            abi.encodePacked(IOracle.value.selector),
            MockProvider.ReturnData({
                success: true,
                data: abi.encode(int256(100 * 10**18), true)
            }),
            false
        );

        bytes32 mockTokenId2 = bytes32(uint256(mockTokenId1) + 1);
        uint256 mockTokenId2MinThreshold = mockTokenId1MinThreshold;
        // Add oracle with rate id
        relayer.oracleAdd(
            address(oracle2),
            mockTokenId2,
            mockTokenId2MinThreshold
        );

        // Execute must call update on all oracles before pushing the values to Collybus
        relayer.execute();

        // Update was called for both oracles
        MockProvider.CallData memory cd1 = oracle1.getCallData(0);
        assertTrue(cd1.functionSelector == IOracle.update.selector);

        MockProvider.CallData memory cd2 = oracle2.getCallData(0);
        assertTrue(cd2.functionSelector == IOracle.update.selector);
    }

    function test_execute_updateDiscountRateInCollybus() public {
        relayer.execute();

        assertTrue(
            collybus.valueForToken(mockTokenId1) ==
                uint256(oracle1InitialValue),
            "Invalid discount rate relayer rate value"
        );
    }

    function test_execute_updateSpotPriceInCollybus() public {
        // Create a spot price relayer and check the spot prices in the Collybus
        Relayer spotPriceRelayer = new Relayer(
            address(collybus),
            IRelayer.RelayerType.SpotPrice
        );
        MockProvider spotPriceOracle = new MockProvider();
        int256 value = int256(1 * 10**18);

        bytes32 mockSpotTokenAddress = bytes32(uint256(1));

        // Set the value returned by the Oracle.
        spotPriceOracle.givenQueryReturnResponse(
            abi.encodePacked(IOracle.value.selector),
            MockProvider.ReturnData({
                success: true,
                data: abi.encode(value, true)
            }),
            false
        );

        // Add oracle with rate id
        spotPriceRelayer.oracleAdd(
            address(spotPriceOracle),
            mockSpotTokenAddress,
            1
        );

        // Update the rates in collybus
        spotPriceRelayer.execute();

        assertTrue(
            collybus.valueForToken(mockSpotTokenAddress) == uint256(value),
            "Invalid spot price relayer spot value"
        );
    }

    function test_execute_doesNotUpdatesRatesInCollybusWhenDeltaIsBelowThreshold()
        public
    {
        // Threshold percentage
        uint256 thresholdPercentage = 50_00; // 50%

        // TokenId
        bytes32 localTokenId = bytes32("percentage_threshold_token_test");

        // Create a local relayer
        Relayer localRelayer = new Relayer(address(collybus), relayerType);

        // Create a local oracle
        MockProvider localOracle = new MockProvider();

        // Set the value returned by the Oracle.
        int256 initialValue = 100;
        localOracle.givenQueryReturnResponse(
            abi.encodePacked(IOracle.value.selector),
            MockProvider.ReturnData({
                success: true,
                data: abi.encode(initialValue, true)
            }),
            false
        );

        // Add oracle with a thresold percentage
        localRelayer.oracleAdd(
            address(localOracle),
            localTokenId,
            thresholdPercentage
        );

        // Make sure the values are updated, start clean
        localRelayer.execute();

        // The initial value is the value we just defined
        assertEq(
            collybus.valueForToken(localTokenId),
            uint256(initialValue),
            "We should have the initial value"
        );

        // Update the oracle with a new value under the threshold limit
        int256 secondValue = initialValue +
            (initialValue * int256(thresholdPercentage)) /
            100_00 -
            1;
        localOracle.givenQueryReturnResponse(
            abi.encodePacked(IOracle.value.selector),
            MockProvider.ReturnData({
                success: true,
                data: abi.encode(secondValue, true)
            }),
            false
        );

        // Relayer should not need to update values since it's below the thresold
        assertTrue(localRelayer.check() == false, "Should not update values");

        // Execute the relayer
        localRelayer.execute();

        // Make sure the new value was not pushed into Collybus
        assertEq(
            collybus.valueForToken(localTokenId),
            uint256(initialValue),
            "Collybus should not have been updated"
        );
    }

    function test_execute_updatesRatesInCollybusWhenDeltaIsAboveThreshold()
        public
    {
        // Threshold percentage
        uint256 thresholdPercentage = 50_00; // 50%

        // TokenId
        bytes32 localTokenId = bytes32("percentage_threshold_token_test");

        // Create a local relayer
        Relayer localRelayer = new Relayer(address(collybus), relayerType);

        // Create a local oracle
        MockProvider localOracle = new MockProvider();

        // Set the value returned by the Oracle.
        int256 initialValue = 100;
        localOracle.givenQueryReturnResponse(
            abi.encodePacked(IOracle.value.selector),
            MockProvider.ReturnData({
                success: true,
                data: abi.encode(initialValue, true)
            }),
            false
        );

        // Add oracle with a thresold percentage
        localRelayer.oracleAdd(
            address(localOracle),
            localTokenId,
            thresholdPercentage
        );

        // Make sure the values are updated, start from `initialValue`
        localRelayer.execute();

        // The initial value is the value we just defined
        assertEq(
            collybus.valueForToken(localTokenId),
            uint256(initialValue),
            "We should have the initial value"
        );

        // Update the oracle with a new value above the threshold limit
        int256 secondValue = initialValue +
            (initialValue * int256(thresholdPercentage)) /
            100_00 +
            1;
        localOracle.givenQueryReturnResponse(
            abi.encodePacked(IOracle.value.selector),
            MockProvider.ReturnData({
                success: true,
                data: abi.encode(secondValue, true)
            }),
            false
        );

        // Relayer should need to update values since it's above the thresold
        assertTrue(localRelayer.check() == true, "Should update values");

        // Execute the relayer
        localRelayer.execute();

        // Make sure the new value was pushed into Collybus
        assertEq(
            collybus.valueForToken(localTokenId),
            uint256(secondValue),
            "Collybus should have the new value"
        );
    }

    function test_executeWithRevert() public {
        // Call should not revert
        relayer.executeWithRevert();
    }

    function test_executeWithRevert_checkWillReturnFalseAfter() public {
        // Call should not revert because check will return true
        relayer.executeWithRevert();

        assertTrue(
            relayer.check() == false,
            "Check should return false after executeWithRevert was called"
        );
    }

    function testFail_executeWithRevert_failsWhenCheckReturnsFalse() public {
        // Update oracles and rates
        relayer.execute();

        // Execute with revert should fail because check will return false
        relayer.executeWithRevert();
    }
}
