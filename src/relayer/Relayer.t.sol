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
        valueForToken[bytes32(abi.encode(tokenId))] = rate;
    }

    function updateSpot(address tokenAddress, uint256 spot)
        external
        override(ICollybus)
    {
        valueForToken[bytes32(abi.encode(tokenAddress))] = spot;
    }
}

contract RelayerTest is DSTest {
    Hevm internal hevm = Hevm(DSTest.HEVM_ADDRESS);
    Relayer internal cdrr;
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
        cdrr = new Relayer(address(collybus), relayerType);

        oracle1 = new MockProvider();

        mockTokenId1 = bytes32(abi.encode(uint256(1)));

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
        cdrr.oracleAdd(
            address(oracle1),
            mockTokenId1,
            mockTokenId1MinThreshold
        );
    }

    function test_deploy() public {
        assertTrue(address(cdrr) != address(0), "Relayer should be deployed");
    }

    function test_check_collybus() public {
        assertEq(cdrr.collybus(), address(collybus));
    }

    function test_check_relayerType() public {
        assertTrue(cdrr.relayerType() == relayerType, "Invalid relayerType");
    }

    function test_check_oracleData() public {
        Relayer.OracleData memory oracleData = cdrr.oraclesData(
            address(oracle1)
        );

        assertTrue(oracleData.exists);
        assertEq(oracleData.lastUpdateValue, 0);
        assertEq(oracleData.tokenId, mockTokenId1);
        assertEq(oracleData.minimumThresholdValue, mockTokenId1MinThreshold);
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
            "CollybusDiscountRateRelayer should contain 1 oracle"
        );
    }

    function test_AddOracle() public {
        // Create a new address that differs from the oracle already added
        address newOracle = address(0x1);
        bytes32 mockTokenId2 = bytes32(
            abi.encode(abi.decode(abi.encode(mockTokenId1), (uint256)) + 1)
        );

        // Add the oracle for a new token ID.
        cdrr.oracleAdd(newOracle, mockTokenId2, mockTokenId1MinThreshold);

        // Check that oracle was added
        assertTrue(cdrr.oracleExists(newOracle), "Oracle should be added");

        // Check the number of existing oracles
        assertTrue(
            cdrr.oracleCount() == 2,
            "CollybusDiscountRateRelayer should contain 2 oracles"
        );
    }

    function testFail_AddOracle_ShouldNotAllowDuplicateOracles() public {
        // Attempt to add the same oracle again but use a different token id.
        bytes32 mockTokenId2 = bytes32(
            abi.encode(abi.decode(abi.encode(mockTokenId1), (uint256)) + 1)
        );

        cdrr.oracleAdd(
            address(oracle1),
            mockTokenId2,
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
        bytes32 mockTokenId2 = bytes32(
            abi.encode(abi.decode(abi.encode(mockTokenId1), (uint256)) + 1)
        );
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

        // Oracle should not exist
        assertTrue(
            cdrr.oracleExists(address(oracle1)) == false,
            "CollybusDiscountRateRelayer oracle should be deleted"
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
        // Set the value returned by the Oracle.
        oracle2.givenQueryReturnResponse(
            abi.encodePacked(IOracle.value.selector),
            MockProvider.ReturnData({
                success: true,
                data: abi.encode(int256(100 * 10**18), true)
            }),
            false
        );

        bytes32 mockTokenId2 = bytes32(
            abi.encode(abi.decode(abi.encode(mockTokenId1), (uint256)) + 1)
        );
        uint256 mockTokenId2MinThreshold = mockTokenId1MinThreshold;
        // Add oracle with rate id
        cdrr.oracleAdd(
            address(oracle2),
            mockTokenId2,
            mockTokenId2MinThreshold
        );

        // Check will search for at least one updatable oracle, which in our case is the first one in the list
        // therefore, the first oracle will be updated but the second will not
        cdrr.check();

        // Update should be the first called function
        MockProvider.CallData memory cd1 = oracle1.getCallData(0);
        assertTrue(cd1.functionSelector == IOracle.update.selector);

        // No function calls for our second oracle
        MockProvider.CallData memory cd2 = oracle2.getCallData(0);
        assertTrue(cd2.functionSelector == bytes4(0));
    }

    function test_Check_ReturnsFalseAfterExecute() public {
        bool checkBeforeUpdate = cdrr.check();
        assertTrue(checkBeforeUpdate);

        cdrr.execute();

        bool checkAfterUpdate = cdrr.check();
        assertTrue(checkAfterUpdate == false);
    }

    function test_ExecuteCalls_UpdateOnAllOracles() public {
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

        bytes32 mockTokenId2 = bytes32(
            abi.encode(abi.decode(abi.encode(mockTokenId1), (uint256)) + 1)
        );
        uint256 mockTokenId2MinThreshold = mockTokenId1MinThreshold;
        // Add oracle with rate id
        cdrr.oracleAdd(
            address(oracle2),
            mockTokenId2,
            mockTokenId2MinThreshold
        );

        // Execute must call update on all oracles before pushing the values to Collybus
        cdrr.execute();

        // Update was called for both oracles
        MockProvider.CallData memory cd1 = oracle1.getCallData(0);
        assertTrue(cd1.functionSelector == IOracle.update.selector);

        MockProvider.CallData memory cd2 = oracle2.getCallData(0);
        assertTrue(cd2.functionSelector == IOracle.update.selector);
    }

    function test_Execute_UpdateDiscountRateInCollybus() public {
        cdrr.execute();

        assertTrue(
            collybus.valueForToken(mockTokenId1) ==
                uint256(oracle1InitialValue),
            "Invalid discount rate relayer rate value"
        );
    }

    function test_Execute_UpdateSpotPriceInCollybus() public {
        // Create a spot price relayer and check the spot prices in the Collybus
        Relayer spotPriceRelayer = new Relayer(
            address(collybus),
            IRelayer.RelayerType.SpotPrice
        );
        MockProvider spotPriceOracle = new MockProvider();
        int256 value = int256(1 * 10**18);

        bytes32 mockSpotTokenAddress = bytes32(abi.encode(address(0x1)));

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

    function test_Execute_DoesNotUpdatesRatesInCollybusWhenDeltaIsBelowThreshold()
        public
    {
        // Execute must call update on all oracles before pushing the values to Collybus
        cdrr.execute();

        // Make the second value returned by the oracle to be just lower than the minimum threshold
        int256 oracleNewValue = oracle1InitialValue +
            int256(mockTokenId1MinThreshold) -
            1;

        oracle1.givenQueryReturnResponse(
            abi.encodePacked(IOracle.value.selector),
            MockProvider.ReturnData({
                success: true,
                data: abi.encode(oracleNewValue, true)
            }),
            false
        );

        cdrr.execute();

        // The rate will NOT be updated because the delta is smaller than the threshold
        assertTrue(
            collybus.valueForToken(mockTokenId1) == uint256(oracle1InitialValue)
        );
    }

    function test_executeWithRevert() public {
        // Call should not revert
        cdrr.executeWithRevert();
    }

    function test_executeWithRevert_checkWillReturnFalseAfter() public {
        // Call should not revert because check will return true
        cdrr.executeWithRevert();

        assertTrue(
            cdrr.check() == false,
            "Check should return false after executeWithRevert was called"
        );
    }

    function testFail_executeWithRevert_failsWhenCheckReturnsFalse() public {
        // Update oracles and rates
        cdrr.execute();

        // Execute with revert should fail because check will return false
        cdrr.executeWithRevert();
    }
}
