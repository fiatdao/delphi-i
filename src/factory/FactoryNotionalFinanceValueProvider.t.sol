// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import "ds-test/test.sol";

import {MockProvider} from "@cleanunicorn/mockprovider/src/MockProvider.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import {FactoryNotionalFinanceValueProvider} from "src/factory/FactoryNotionalFinanceValueProvider.sol";

import {NotionalFinanceValueProvider} from "src/oracle_implementations/discount_rate/NotionalFinance/NotionalFinanceValueProvider.sol";

contract FactoryNotionalFinanceValueProviderTest is DSTest {
    uint256 private _oracleUpdateWindow;
    uint256 private _oracleMaxValidTime;
    int256 private _oracleAlpha;

    address private _notionalView;
    uint16 private _currencyId;
    uint256 private _maturityDate;
    uint256 private _settlementDate;
    uint256 private _oracleRateDecimals;

    FactoryNotionalFinanceValueProvider private factory;

    function setUp() public {
        factory = new FactoryNotionalFinanceValueProvider();
    }

    function test_deploy() public {
        assertTrue(address(factory) != address(0));
    }

    function test_create() public {
        // Create Notional Value Provider
        address notionalValueProviderAddress = factory.create(
            _oracleUpdateWindow,
            _oracleMaxValidTime,
            _oracleAlpha,
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
        address notionalValueProviderAddress = factory.create(
            _oracleUpdateWindow,
            _oracleMaxValidTime,
            _oracleAlpha,
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
                .maxValidTime(),
            _oracleMaxValidTime,
            "Notional Value Provider incorrect maxValidTime"
        );

        assertEq(
            NotionalFinanceValueProvider(notionalValueProviderAddress).alpha(),
            _oracleAlpha,
            "Notional Value Provider incorrect alpha"
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
