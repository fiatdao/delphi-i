// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import "ds-test/test.sol";
import "../../../test/utils/Caller.sol";
import {Hevm} from "../../../test/utils/Hevm.sol";
import {CheatCodes} from "../../../test/utils/CheatCodes.sol";
import {Convert} from "../utils/Convert.sol";
import {MockProvider} from "@cleanunicorn/mockprovider/src/MockProvider.sol";
import {YieldValueProvider} from "./YieldValueProvider.sol";
import {IYieldPool} from "./IYieldPool.sol";

contract YieldValueProviderHelper is YieldValueProvider {
    constructor(
        // Oracle parameters
        uint256 timeUpdateWindow_,
        // Yield specific parameters
        address poolAddress_,
        uint256 maturity_,
        int256 timeScale_,
        uint256 timestamp_,
        uint256 balancesRatio_
    )
        YieldValueProvider(
            timeUpdateWindow_,
            poolAddress_,
            maturity_,
            timeScale_,
            timestamp_,
            balancesRatio_
        )
    {
        // Suppress warning
        this;
    }

    function testGetValue() public returns (int256) {
        return this.getValue();
    }
}

contract YieldValueProviderTest is DSTest, Convert {
    CheatCodes internal cheatCodes = CheatCodes(HEVM_ADDRESS);

    MockProvider internal mockValueProvider;

    YieldValueProvider internal yieldVP;

    // Values taken from contract
    // https://etherscan.io/address/0xEf82611C6120185D3BF6e020D1993B49471E7da0
    // at block 14834025 and block 14841073
    uint256 private _maturity = 1648177200;
    int256 private _timeScale = 3168808781; // computed from 58454204609 which is in 64.64 format
    uint256 private _cumulativeBalancesRatio =
        17436777487921011541386713127552896;
    uint32 private _blockTime = 1653460663;

    uint256 private _startBlockTimestamp = 1653370980;
    uint256 private _startCumulativeBalanceRatio =
        17330732019965844784580556706346119;

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
            int256(_timeScale),
            _startBlockTimestamp,
            _startCumulativeBalanceRatio
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
            uconvert(_startCumulativeBalanceRatio, 27, 18),
            "Invalid cumulativeBalanceRatioLast"
        );
    }

    function test_check_balanceTimestampLast() public {
        assertEq(
            yieldVP.balanceTimestampLast(),
            _startBlockTimestamp,
            "Invalid balanceTimestampLast"
        );
    }

    function test_getValue_failsWhenCalledByOthers() public {
        cheatCodes.expectRevert(
            abi.encodeWithSelector(
                YieldValueProvider
                    .YieldProtocolValueProvider__getValue_onlyOracleCanCall
                    .selector
            )
        );
        yieldVP.getValue();
    }

    function test_getValue() public {
        // In order to test the getValue method we will wrap the yield value provider contract
        // inside another helper contract witch exposes the getValue method
        YieldValueProviderHelper yieldHelper = new YieldValueProviderHelper(
            // Oracle arguments
            // Time update window
            _timeUpdateWindow,
            // Yield arguments
            address(mockValueProvider),
            uint256(_maturity),
            int256(_timeScale),
            _startBlockTimestamp,
            _startCumulativeBalanceRatio
        );

        int256 expectedValue = 531050252;
        setMockValues(
            mockValueProvider,
            17436777487921011541386713127552896,
            1653460663
        );

        assertTrue(yieldHelper.testGetValue() == expectedValue);
    }

    function testFail_getValue_revertsOnOrAfterMaturityDate() public {
        cheatCodes.warp(yieldVP.maturity());
        yieldVP.getValue();
    }
}
