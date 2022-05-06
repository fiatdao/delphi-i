// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import "ds-test/test.sol";
import "../../../test/utils/Caller.sol";
import {Hevm} from "../../../test/utils/Hevm.sol";
import {Convert} from "../utils/Convert.sol";
import {MockProvider} from "@cleanunicorn/mockprovider/src/MockProvider.sol";
import {YieldValueProvider} from "./YieldValueProvider.sol";
import {IYieldPool} from "./IYieldPool.sol";

contract YieldValueProviderTest is DSTest, Convert {
    Hevm internal hevm = Hevm(DSTest.HEVM_ADDRESS);

    MockProvider internal mockValueProvider;

    YieldValueProvider internal yieldVP;

    // Values taken from contract
    // https://etherscan.io/token/0x3771c99c087a81df4633b50d8b149afaa83e3c9e
    // at block 13911954
    uint256 private _maturity = 1648177200;
    int256 private _timeScale = 3168808781; // computed from 58454204609 which is in 64.64 format
    uint112 private _cumulativeBalancesRatio =
        5141501570599198210548627855691773;
    uint32 private _blockTime = 1639432842;

    // Default oracle parameters
    uint256 private _timeUpdateWindow = 100; // seconds

    function setUp() public {
        mockValueProvider = new MockProvider();

        setMockValues(mockValueProvider, _cumulativeBalancesRatio, _blockTime);

        yieldVP = new YieldValueProvider(
            // Oracle arguments
            // Time update window
            _timeUpdateWindow,
            // Yield arguments
            address(mockValueProvider),
            uint256(_maturity),
            int256(_timeScale)
        );
    }

    function setMockValues(
        MockProvider mockValueProvider_,
        uint256 cumulativeBalancesRatio_,
        uint32 blocktime_
    ) internal {
        // Set the  getCache values returned by the pool contract
        mockValueProvider_.givenQueryReturnResponse(
            abi.encodePacked(IYieldPool.getCache.selector),
            MockProvider.ReturnData({
                success: true,
                data: abi.encode(0, 0, blocktime_)
            }),
            false
        );

        // Set the cumulativeBalancesRatio returned by the pool contract
        mockValueProvider_.givenQueryReturnResponse(
            abi.encodePacked(IYieldPool.cumulativeBalancesRatio.selector),
            MockProvider.ReturnData({
                success: true,
                data: abi.encode(cumulativeBalancesRatio_)
            }),
            false
        );
    }

    function test_deploy() public {
        assertTrue(
            address(yieldVP) != address(0),
            "Yield value provider should be deployed"
        );
    }

    function test_check_poolId() public {
        assertTrue(
            yieldVP.poolAddress() != address(0),
            "Yield pool address should be valid"
        );
    }

    function test_check_maturity() public {
        assertEq(yieldVP.maturity(), _maturity, "Invalid maturity date");
    }

    function test_check_timeScale() public {
        assertEq(yieldVP.timeScale(), _timeScale, "Invalid time scale value");
    }

    function test_check_cumulativeBalanceRatioLast() public {
        assertEq(
            yieldVP.cumulativeBalanceRatioLast(),
            uconvert(_cumulativeBalancesRatio, 27, 18),
            "Invalid cumulativeBalanceRatioLast"
        );
    }

    function test_check_blockTimestampLast() public {
        assertEq(
            yieldVP.blockTimestampLast(),
            _blockTime,
            "Invalid blockTimestampLast"
        );
    }

    function test_getValue() public {
        // Values take from contract
        // https://etherscan.io/token/0x3771c99c087a81df4633b50d8b149afaa83e3c9e
        // at block 13800244
        int256 expectedValue = 1204540138;
        setMockValues(
            mockValueProvider,
            7342183639948751441026554744281105,
            1640937617
        );
        int256 value = yieldVP.getValue();
        assertTrue(value == expectedValue);
    }

    function testFail_getValue_revertsOnOrAfterMaturityDate() public {
        hevm.warp(yieldVP.maturity());
        yieldVP.getValue();
    }
}
