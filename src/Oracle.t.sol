// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import "ds-test/test.sol";

import "./test/utils/Caller.sol";
import {Hevm} from "./test/utils/Hevm.sol";
import {MockProvider} from "./test/utils/MockProvider.sol";
import {IValueProvider} from "./valueprovider/IValueProvider.sol";

import {Oracle} from "./Oracle.sol";

contract OracleTest is DSTest {
    Hevm hevm = Hevm(DSTest.HEVM_ADDRESS);

    MockProvider mp;
    Oracle oracle;
    uint256 windowLength = 10;
    uint256 minTimeBetweenWindows = 100; // seconds

    function setUp() public {
        mp = new MockProvider();
        oracle = new Oracle(address(mp), windowLength, minTimeBetweenWindows);

        hevm.warp(1000);
        hevm.roll(1000);
    }

    function test_deploy() public {
        assertTrue(address(oracle) != address(0));
    }

    function test_getValue_CallsIntoValueGetter() public {
        // ValueProvider should return a value of 1
        mp.givenQueryReturnResponse(
            abi.encodePacked(IValueProvider.getValue.selector),
            MockProvider.ReturnData({
                success: true,
                data: abi.encode(uint256(1))
            })
        );

        // Requesting a value from oracle will also trigger a value request
        oracle.getValue();

        // Check if the ValueProvider was called by the Oracle
        MockProvider.CallData memory cd = mp.getCallData(0);
        assertEq(cd.caller, address(oracle), "Oracle should be the caller");
        assertEq(
            cd.functionSelector,
            IValueProvider.getValue.selector,
            "Oracle should ask ValueProvider for current value"
        );
    }

    function test_update_Updates_timestamp() public {
        oracle.update();

        // Check if the timestamp was updated
        assertEq(oracle.lastTimestamp(), block.timestamp);
        assertEq(oracle.lastBlock(), block.number);
    }

    function test_update_ShouldNotUpdatePreviousValues_IfNotEnoughTimePassed()
        public
    {
        oracle.update();

        uint256 blockNumber = block.number;
        uint256 blockTimestamp = block.timestamp;

        // Check if the timestamp was updated
        assertEq(oracle.lastTimestamp(), blockNumber);
        assertEq(oracle.lastBlock(), blockTimestamp);

        // Advance time
        hevm.warp(blockTimestamp + minTimeBetweenWindows - 1);
        hevm.roll(blockNumber + 1);

        // Calling update should not update the values
        // because not enough time has passed
        oracle.update();

        // Check if the values are still the same
        assertEq(oracle.lastTimestamp(), blockNumber);
        assertEq(oracle.lastBlock(), blockTimestamp);
    }

    function test_update_ShouldUpdatePreviousValues_IfEnoughTimePassed()
        public
    {
        oracle.update();

        uint256 blockNumber = block.number;
        uint256 blockTimestamp = block.timestamp;

        // Check if the timestamp was updated
        assertEq(oracle.lastTimestamp(), blockNumber);
        assertEq(oracle.lastBlock(), blockTimestamp);

        // Advance time
        hevm.warp(blockNumber + minTimeBetweenWindows + 1);
        hevm.roll(blockTimestamp + 1);

        // Calling update should not update the values
        // because not enough time has passed
        oracle.update();

        // Check if the values are still the same
        assertEq(
            oracle.lastTimestamp(),
            blockNumber + minTimeBetweenWindows + 1
        );
        assertEq(oracle.lastBlock(), blockTimestamp + 1);
    }
}
