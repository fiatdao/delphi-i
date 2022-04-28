// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import "ds-test/test.sol";
import "../../../test/utils/Caller.sol";
import {Hevm} from "../../../test/utils/Hevm.sol";
import {CheatCodes} from "../../../test/utils/CheatCodes.sol";
import {MockProvider} from "@cleanunicorn/mockprovider/src/MockProvider.sol";
import {INotionalView} from "./INotionalView.sol";
import {MarketParameters} from "./INotionalView.sol";
import {NotionalFinanceValueProvider} from "./NotionalFinanceValueProvider.sol";

contract NotionalFinanceValueProviderTest is DSTest {
    CheatCodes internal cheatCodes = CheatCodes(HEVM_ADDRESS);

    MockProvider internal mockNotionalView;

    NotionalFinanceValueProvider internal notionalVP;

    uint16 internal _currencyId = 2;
    uint256 internal _maturityDate = 1671840000;
    uint256 internal _timeUpdateWindow = 100; // seconds

    function setUp() public {
        // Values taken from interrogating the active markets via the Notional View Contract deployed at
        // 0x1344A36A1B56144C3Bc62E7757377D288fDE0369
        // block: 13979660
        mockNotionalView = new MockProvider();

        notionalVP = new NotionalFinanceValueProvider(
            // Oracle arguments
            // Time update window
            _timeUpdateWindow,
            // Notional Finance arguments
            address(mockNotionalView),
            _currencyId,
            9,
            _maturityDate
        );
    }

    function test_deploy() public {
        assertTrue(address(notionalVP) != address(0));
    }

    function test_check_notionalView() public {
        // Check the address of the notional view contract
        assertEq(notionalVP.notionalView(), address(mockNotionalView));
    }

    function test_check_currencyId() public {
        // Check the currency Id is correctly set
        assertEq(notionalVP.currencyId(), _currencyId);
    }

    function test_check_maturityDate() public {
        // Check the maturity date
        assertEq(notionalVP.maturityDate(), _maturityDate);
    }

    function test_getValue() public {
        mockNotionalView.givenQueryReturnResponse(
            // Used Parameters are: currency ID, maturity date and settlement date.
            abi.encodeWithSelector(
                INotionalView.getMarket.selector,
                _currencyId,
                _maturityDate,
                notionalVP.getSettlementDate()
            ),
            MockProvider.ReturnData({
                success: true,
                data: abi.encode(
                    MarketParameters({
                        storageSlot: bytes32(
                            0xc0ddee3e85a71c2541e1bd9f87cf75833c3860ea32afc5fab9589fd51748147b
                        ),
                        maturity: _maturityDate,
                        totalfCash: int256(7134342186012091),
                        totalAssetCash: int256(222912257923357058),
                        totalLiquidity: int256(221856382336730813),
                        lastImpliedRate: uint256(88688026),
                        oracleRate: uint256(88688026),
                        previousTradeTime: uint256(1641600791)
                    })
                )
            }),
            false
        );

        // Expected value is the lastImpliedRate(1e9 precision) in 1e18 precision
        int256 expectedValue = 2851338287;

        // Computed value based on the parameters that are sent via the mock provider
        int256 value = notionalVP.getValue();
        assertTrue(value == expectedValue);
    }

    function testFail_getValue_revertsOnOrAfterMaturityDate() public {
        cheatCodes.warp(notionalVP.maturityDate());
        notionalVP.getValue();
    }

    function test_getValue_failsWithInvalidMarketParameters() public {
        // Update the mock to return an un-initialized market
        mockNotionalView.givenQueryReturnResponse(
            abi.encodeWithSelector(
                INotionalView.getMarket.selector,
                _currencyId,
                _maturityDate,
                notionalVP.getSettlementDate()
            ),
            MockProvider.ReturnData({
                success: true,
                data: abi.encode(
                    MarketParameters({
                        storageSlot: bytes32(
                            0xc0ddee3e85a71c2541e1bd9f87cf75833c3860ea32afc5fab9589fd51748147b
                        ),
                        maturity: _maturityDate,
                        totalfCash: int256(0),
                        totalAssetCash: int256(0),
                        totalLiquidity: int256(0),
                        lastImpliedRate: uint256(0),
                        oracleRate: uint256(0),
                        previousTradeTime: uint256(0)
                    })
                )
            }),
            false
        );

        // Call should revert because of the invalid market
        cheatCodes.expectRevert(
            abi.encodeWithSelector(
                NotionalFinanceValueProvider
                    .NotionalFinanceValueProvider__getValue_invalidMarketParameters
                    .selector,
                _currencyId,
                _maturityDate,
                notionalVP.getSettlementDate()
            )
        );
        notionalVP.getValue();
    }
}
