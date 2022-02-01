// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import "ds-test/test.sol";

import "src/test/utils/Caller.sol";
import {Hevm} from "src/test/utils/Hevm.sol";
import {MockProvider} from "src/test/utils/MockProvider.sol";
import {INotionalView} from "./INotionalView.sol";
import {MarketParameters} from "./INotionalView.sol";

import {NotionalFinanceValueProvider} from "./NotionalFinanceValueProvider.sol";

contract NotionalFinanceValueProviderTest is DSTest {
    Hevm internal hevm = Hevm(DSTest.HEVM_ADDRESS);

    MockProvider internal mockNotionalView;

    NotionalFinanceValueProvider internal notionalVP;

    uint16 internal _currencyID = 2;
    uint256 internal _maturityDate = 1671840000;
    uint256 internal _settlementDate = 1648512000;
    uint256 internal _timeUpdateWindow = 100; // seconds
    uint256 internal _maxValidTime = 300;
    int256 internal _alpha = 2 * 10**17; // 0.2

    function setUp() public {
        // Values taken from interrogating the active markets via the Notional View Contract deployed at
        // 0x1344A36A1B56144C3Bc62E7757377D288fDE0369
        // block: 13979660
        mockNotionalView = new MockProvider();
        mockNotionalView.givenQueryReturnResponse(
            // Used Parameters are: currency ID, maturity date and settlement date.
            abi.encodeWithSelector(
                INotionalView.getMarket.selector,
                _currencyID,
                uint256(1671840000),
                uint256(1648512000)
            ),
            MockProvider.ReturnData({
                success: true,
                data: abi.encode(
                    MarketParameters({
                        storageSlot: bytes32(
                            0xc0ddee3e85a71c2541e1bd9f87cf75833c3860ea32afc5fab9589fd51748147b
                        ),
                        maturity: uint256(1671840000),
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

        notionalVP = new NotionalFinanceValueProvider(
            // Oracle arguments
            // Time update window
            _timeUpdateWindow,
            // Max valid time
            _maxValidTime,
            // Alpha
            _alpha,
            // Notional Finance arguments
            address(mockNotionalView),
            _currencyID,
            9,
            _maturityDate,
            _settlementDate
        );
    }

    function test_deploy() public {
        assertTrue(address(notionalVP) != address(0));
    }

    function test_check_notionalView() public {
        assertEq(notionalVP.notionalView(), address(mockNotionalView));
    }

    function test_check_currencyID() public {
        assertEq(notionalVP.currencyID(), _currencyID);
    }

    function test_check_maturityDate() public {
        assertEq(notionalVP.maturityDate(), _maturityDate);
    }

    function test_check_settlementDate() public {
        assertEq(notionalVP.settlementDate(), _settlementDate);
    }

    function test_GetValue() public {
        // Expected value is the lastImpliedRate(1e9 precision) in 1e18 precision
        int256 expectedValue = 2851338287; //2810353955;

        // Computed value based on the parameters that are sent via the mock provider
        int256 value = notionalVP.getValue();
        assertTrue(value == expectedValue);
    }
}
