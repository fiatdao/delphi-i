// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import {Hevm} from "src/test/utils/Hevm.sol";
import {DSTest} from "lib/ds-test/src/test.sol";
import {MockProvider} from "src/test/utils/MockProvider.sol";
import {Caller} from "src/test/utils/Caller.sol";

import {ICollybus} from "src/relayer/ICollybus.sol";
import {CollybusSpotPriceRelayer} from "./CollybusSpotPriceRelayer.sol";
import {IOracle} from "src/oracle/IOracle.sol";
import {IValueProvider} from "src/valueprovider/IValueProvider.sol";

contract TestCollybus is ICollybus {
    mapping(address => uint256) public rateForTokenAddress;

    function updateSpot(address tokenAddress, uint256 rate)
        external
        override(ICollybus)
    {
        rateForTokenAddress[tokenAddress] = rate;
    }

    function updateDiscountRate(uint256 tokenId, uint256 rate)
        public
        override(ICollybus)
    {}
}

contract CollybusDiscountRateRelayerTest is DSTest {
    Hevm internal hevm = Hevm(DSTest.HEVM_ADDRESS);
    CollybusSpotPriceRelayer internal cdrr;
    TestCollybus internal collybus;

    MockProvider internal oracle1;

    uint256 internal oracleTimeUpdateWindow = 100; // seconds
    uint256 internal oracleMaxValidTime = 300;
    int256 internal oracleAlpha = 2 * 10**17; // 0.2

    address internal mockToken1Address = address(0x1);
    address internal mockToken2Address = address(0x2);
    uint256 internal mockToken1MinThreshold = 1;
    uint256 internal mockToken2MinThreshold = 1;

    function setUp() public {
        collybus = new TestCollybus();
        cdrr = new CollybusSpotPriceRelayer(address(collybus));

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
            mockToken1Address,
            mockToken1MinThreshold
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
        // Create a new address that differs from the oracle already added
        address newOracle = address(0x1);

        // Add the second oracle for a new token address
        cdrr.oracleAdd(newOracle, mockToken2Address, mockToken2MinThreshold);
    }

    function testFail_AddOracle_ShouldNotAllowDuplicateOracles() public {
        // Attempt to add the same oracle again but use a different token address
        cdrr.oracleAdd(
            address(oracle1),
            mockToken2Address,
            mockToken2MinThreshold
        );
    }

    function testFail_AddOracle_ShouldNotAllowDuplicateTokenIds() public {
        // Create a new address that differs from the oracle already added
        address newOracle = address(0x1);
        // Add a new oracle that has the same token id as the previously added oracle.
        cdrr.oracleAdd(
            address(newOracle),
            mockToken1Address,
            mockToken1MinThreshold
        );
    }

    function test_AddOracle_OnlyAuthorizedUserShouldBeAbleToAdd() public {
        Caller user = new Caller();

        address newOracle = address(0x1);
        // Add the oracle
        (bool ok, ) = user.externalCall(
            address(cdrr),
            abi.encodeWithSelector(
                cdrr.oracleAdd.selector,
                newOracle,
                mockToken2Address,
                mockToken2MinThreshold
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

        // Add oracle with rate id
        cdrr.oracleAdd(
            address(oracle2),
            mockToken2Address,
            mockToken2MinThreshold
        );
        hevm.warp(oracleTimeUpdateWindow);

        // Check will search for at least one updatable oracle, which in our case is the first one in the list
        // therefore, the first oracle will be updated but the second will not.
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

        // Add oracle with rate id
        cdrr.oracleAdd(
            address(oracle2),
            mockToken2Address,
            mockToken2MinThreshold
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

        // Add oracle with rate id.
        cdrr.oracleAdd(
            address(oracle2),
            mockToken2Address,
            mockToken2MinThreshold
        );
        hevm.warp(oracleTimeUpdateWindow);

        // Execute must call update on all oracles before pushing the values to Collybus.
        // Check should trigger an update because the value delta is bigger than the minimum for both oracles.
        bool mustUpdate = cdrr.check();
        assertTrue(mustUpdate);

        cdrr.execute();

        assertTrue(
            collybus.rateForTokenAddress(mockToken1Address) ==
                uint256(100 * 10**18)
        );
        assertTrue(
            collybus.rateForTokenAddress(mockToken2Address) ==
                uint256(10 * 10**18)
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

        mockToken2MinThreshold = 1 * 10**18;
        // Add oracle with rate id
        cdrr.oracleAdd(
            address(oracle2),
            mockToken2Address,
            mockToken2MinThreshold
        );
        hevm.warp(oracleTimeUpdateWindow);

        // Execute must call update on all oracles before pushing the values to Collybus.
        cdrr.check();
        cdrr.execute();

        // Make the second value returned by the oracle to be just lower than the minimum threshold
        int256 oracle2NewValue = oracle2InitialValue +
            int256(mockToken2MinThreshold) -
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

        // The rate will NOT be updated because the delta is smaller than the threshold.
        assertTrue(
            collybus.rateForTokenAddress(mockToken2Address) ==
                uint256(oracle2InitialValue)
        );
    }
}
