// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import "ds-test/test.sol";

import {MockProvider} from "@cleanunicorn/mockprovider/src/MockProvider.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {NotionalFinanceFactory} from "./NotionalFinanceFactory.sol";
import {NotionalFinanceValueProvider} from "../oracle_implementations/discount_rate/NotionalFinance/NotionalFinanceValueProvider.sol";
import {Relayer} from "../relayer/Relayer.sol";
import {IRelayer} from "../relayer/IRelayer.sol";

contract NotionalFinanceFactoryTest is DSTest {
    address private _collybusAddress = address(0xC011b005);
    uint256 private _oracleUpdateWindow = 1 * 3600;
    uint256 private _tokenId = 1;
    uint256 private _minimumPercentageDeltaValue = 25;

    address private _notionalView;
    uint256 private _currencyId = 2;
    uint256 private _lastImpliedRateDecimals = 9;
    uint256 private _maturityDate = 1671840000;
    uint256 private _settlementDate = 1648512000;

    NotionalFinanceFactory private _factory;

    function setUp() public {
        _factory = new NotionalFinanceFactory();
    }

    function test_deploy() public {
        assertTrue(address(_factory) != address(0));
    }

    function test_create_relayerIsDeployed() public {
        // Create Notional Relayer
        address notionalRelayerAddress = _factory.create(
            _collybusAddress,
            _tokenId,
            _minimumPercentageDeltaValue,
            _oracleUpdateWindow,
            _notionalView,
            _currencyId,
            _lastImpliedRateDecimals,
            _maturityDate,
            _settlementDate
        );

        assertTrue(
            notionalRelayerAddress != address(0),
            "Factory Notional Relayer create failed"
        );
    }

    function test_create_oracleIsDeployed() public {
        // Create Notional Relayer
        address notionalRelayerAddress = _factory.create(
            _collybusAddress,
            _tokenId,
            _minimumPercentageDeltaValue,
            _oracleUpdateWindow,
            _notionalView,
            _currencyId,
            _lastImpliedRateDecimals,
            _maturityDate,
            _settlementDate
        );

        Relayer notionalRelayer = Relayer(notionalRelayerAddress);

        assertTrue(
            notionalRelayer.oracle() != address(0),
            "Invalid oracle address"
        );
    }

    function test_create_validateRelayerProperties() public {
        // Create Notional Relayer
        address notionalRelayerAddress = _factory.create(
            _collybusAddress,
            _tokenId,
            _minimumPercentageDeltaValue,
            _oracleUpdateWindow,
            _notionalView,
            _currencyId,
            _lastImpliedRateDecimals,
            _maturityDate,
            _settlementDate
        );

        assertEq(
            Relayer(notionalRelayerAddress).collybus(),
            _collybusAddress,
            "Notional Relayer incorrect Collybus address"
        );

        assertTrue(
            Relayer(notionalRelayerAddress).relayerType() ==
                IRelayer.RelayerType.DiscountRate,
            "Notional Relayer incorrect RelayerType"
        );

        assertEq(
            Relayer(notionalRelayerAddress).encodedTokenId(),
            bytes32(_tokenId),
            "Notional Relayer incorrect tokenId"
        );

        assertEq(
            Relayer(notionalRelayerAddress).minimumPercentageDeltaValue(),
            _minimumPercentageDeltaValue,
            "Notional Relayer incorrect minimumPercentageDeltaValue"
        );
    }

    function test_create_validateOracleProperties() public {
        // Create Notional Relayer
        address notionalRelayerAddress = _factory.create(
            _collybusAddress,
            _tokenId,
            _minimumPercentageDeltaValue,
            _oracleUpdateWindow,
            _notionalView,
            _currencyId,
            _lastImpliedRateDecimals,
            _maturityDate,
            _settlementDate
        );

        address oracleAddress = Relayer(notionalRelayerAddress).oracle();
        // Test that properties are correctly set
        assertEq(
            NotionalFinanceValueProvider(oracleAddress).timeUpdateWindow(),
            _oracleUpdateWindow,
            "Notional Value Provider incorrect timeUpdateWindow"
        );

        assertEq(
            NotionalFinanceValueProvider(oracleAddress).notionalView(),
            _notionalView,
            "Notional Value Provider incorrect notionalView"
        );

        assertEq(
            NotionalFinanceValueProvider(oracleAddress).currencyId(),
            _currencyId,
            "Notional Value Provider incorrect currencyId"
        );

        assertEq(
            NotionalFinanceValueProvider(oracleAddress).maturityDate(),
            _maturityDate,
            "Notional Value Provider incorrect maturityDate"
        );

        assertEq(
            NotionalFinanceValueProvider(oracleAddress).settlementDate(),
            _settlementDate,
            "Notional Value Provider incorrect settlementDate"
        );
    }

    function test_create_factoryPassesRelayerPermissions() public {
        // Create Notional Value Provider
        address notionalRelayerAddress = _factory.create(
            _collybusAddress,
            _tokenId,
            _minimumPercentageDeltaValue,
            _oracleUpdateWindow,
            _notionalView,
            _currencyId,
            _lastImpliedRateDecimals,
            _maturityDate,
            _settlementDate
        );

        Relayer notionalRelayer = Relayer(notionalRelayerAddress);

        bool factoryIsAuthorized = notionalRelayer.canCall(
            notionalRelayer.ANY_SIG(),
            address(_factory)
        );
        assertTrue(
            factoryIsAuthorized == false,
            "The Factory should not have rights over the created contract"
        );

        bool callerIsAuthorized = notionalRelayer.canCall(
            notionalRelayer.ANY_SIG(),
            address(this)
        );
        assertTrue(
            callerIsAuthorized,
            "Caller should have rights over the created contract"
        );
    }

    function test_create_factoryPassesOraclePermissions() public {
        // Create Notional Value Provider
        address notionalRelayerAddress = _factory.create(
            _collybusAddress,
            _tokenId,
            _minimumPercentageDeltaValue,
            _oracleUpdateWindow,
            _notionalView,
            _currencyId,
            _lastImpliedRateDecimals,
            _maturityDate,
            _settlementDate
        );

        NotionalFinanceValueProvider oracle = NotionalFinanceValueProvider(
            Relayer(notionalRelayerAddress).oracle()
        );
        bool factoryIsAuthorized = oracle.canCall(
            oracle.ANY_SIG(),
            address(_factory)
        );
        assertTrue(
            factoryIsAuthorized == false,
            "The Factory should not have rights over the created contract"
        );

        bool callerIsAuthorized = oracle.canCall(
            oracle.ANY_SIG(),
            address(this)
        );
        assertTrue(
            callerIsAuthorized,
            "Caller should have rights over the created contract"
        );
    }
}
