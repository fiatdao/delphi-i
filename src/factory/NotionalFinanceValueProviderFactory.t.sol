// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import "ds-test/test.sol";

import {MockProvider} from "@cleanunicorn/mockprovider/src/MockProvider.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {NotionalFinanceValueProviderFactory} from "./NotionalFinanceValueProviderFactory.sol";
import {NotionalFinanceValueProvider} from "../oracle_implementations/discount_rate/NotionalFinance/NotionalFinanceValueProvider.sol";

contract NotionalFinanceValueProviderFactoryTest is DSTest {
    uint256 private _oracleUpdateWindow;
    uint256 private _oracleMaxValidTime;
    int256 private _oracleAlpha = 1;

    address private _notionalView;
    uint16 private _currencyId;
    uint256 private _maturityDate;
    uint256 private _settlementDate;
    uint256 private _oracleRateDecimals;

    NotionalFinanceValueProviderFactory private _factory;

    function setUp() public {
        _factory = new NotionalFinanceValueProviderFactory();
    }

    function test_deploy() public {
        assertTrue(address(_factory) != address(0));
    }

    function test_create() public {
        // Create Notional Value Provider
        address notionalValueProviderAddress = _factory.create(
            _oracleUpdateWindow,
            _notionalView,
            _currencyId,
            _maturityDate,
            _settlementDate,
            _oracleRateDecimals
        );

        assertTrue(
            notionalValueProviderAddress != address(0),
            "Factory Notional Value Provider create failed"
        );
    }

    function test_create_validateProperties() public {
        // Create Notional Value Provider
        address notionalValueProviderAddress = _factory.create(
            _oracleUpdateWindow,
            _notionalView,
            _currencyId,
            _maturityDate,
            _settlementDate,
            _oracleRateDecimals
        );

        // Test that properties are correctly set
        assertEq(
            NotionalFinanceValueProvider(notionalValueProviderAddress)
                .timeUpdateWindow(),
            _oracleUpdateWindow,
            "ElementFi Value Provider incorrect timeUpdateWindow"
        );

        assertEq(
            NotionalFinanceValueProvider(notionalValueProviderAddress)
                .notionalView(),
            _notionalView,
            "Notional Value Provider incorrect notionalView"
        );

        assertEq(
            NotionalFinanceValueProvider(notionalValueProviderAddress)
                .currencyId(),
            _currencyId,
            "Notional Value Provider incorrect currencyId"
        );

        assertEq(
            NotionalFinanceValueProvider(notionalValueProviderAddress)
                .maturityDate(),
            _maturityDate,
            "Notional Value Provider incorrect maturityDate"
        );

        assertEq(
            NotionalFinanceValueProvider(notionalValueProviderAddress)
                .settlementDate(),
            _settlementDate,
            "Notional Value Provider incorrect settlementDate"
        );
    }
}
