// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import "ds-test/test.sol";

import {MockProvider} from "@cleanunicorn/mockprovider/src/MockProvider.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import {FactoryElementFiValueProvider} from "src/factory/FactoryElementFiValueProvider.sol";

import {ElementFiValueProvider} from "src/oracle_implementations/discount_rate/ElementFi/ElementFiValueProvider.sol";

contract FactoryElementFiValueProviderTest is DSTest {
    uint256 private _oracleUpdateWindow;
    uint256 private _oracleMaxValidTime;
    int256 private _oracleAlpha;

    bytes32 private _poolId =
        bytes32(
            0x6dd0f7c8f4793ed2531c0df4fea8633a21fdcff40002000000000000000000b7
        );
    address private _balancerVaultAddress = address(0x123);
    int256 private _timeScale = 2426396518;
    uint256 private _maturity = 1651275535;

    FactoryElementFiValueProvider private _factory;

    function setUp() public {
        _factory = new FactoryElementFiValueProvider();
    }

    function test_deploy() public {
        assertTrue(address(_factory) != address(0));
    }

    function test_create() public {
        // Create mock ERC20 tokens needed to create the value provider
        MockProvider underlierMock = new MockProvider();
        underlierMock.givenQueryReturnResponse(
            abi.encodeWithSelector(ERC20.decimals.selector),
            MockProvider.ReturnData({
                success: true,
                data: abi.encode(uint8(18))
            }),
            false
        );

        MockProvider ePTokenBondMock = new MockProvider();
        ePTokenBondMock.givenQueryReturnResponse(
            abi.encodeWithSelector(ERC20.decimals.selector),
            MockProvider.ReturnData({
                success: true,
                data: abi.encode(uint8(18))
            }),
            false
        );

        MockProvider poolToken = new MockProvider();
        poolToken.givenQueryReturnResponse(
            abi.encodeWithSelector(ERC20.decimals.selector),
            MockProvider.ReturnData({
                success: true,
                data: abi.encode(uint8(18))
            }),
            false
        );

        // Create ElementFi Value Provider
        address elementValueProviderAddress = _factory.create(
            _oracleUpdateWindow,
            _oracleMaxValidTime,
            _oracleAlpha,
            _poolId,
            _balancerVaultAddress,
            address(poolToken),
            address(underlierMock),
            address(ePTokenBondMock),
            _timeScale,
            _maturity
        );

        assertTrue(
            elementValueProviderAddress != address(0),
            "Factory ElementFi Value Provider create failed"
        );
    }

    function test_create_validateProperties() public {
        // Create mock ERC20 tokens needed to create the value provider
        MockProvider underlierMock = new MockProvider();
        underlierMock.givenQueryReturnResponse(
            abi.encodeWithSelector(ERC20.decimals.selector),
            MockProvider.ReturnData({
                success: true,
                data: abi.encode(uint8(18))
            }),
            false
        );

        MockProvider ePTokenBondMock = new MockProvider();
        ePTokenBondMock.givenQueryReturnResponse(
            abi.encodeWithSelector(ERC20.decimals.selector),
            MockProvider.ReturnData({
                success: true,
                data: abi.encode(uint8(18))
            }),
            false
        );

        MockProvider poolTokenMock = new MockProvider();
        poolTokenMock.givenQueryReturnResponse(
            abi.encodeWithSelector(ERC20.decimals.selector),
            MockProvider.ReturnData({
                success: true,
                data: abi.encode(uint8(18))
            }),
            false
        );

        // Create the ElementFi Value Provider
        address elementValueProviderAddress = _factory.create(
            _oracleUpdateWindow,
            _oracleMaxValidTime,
            _oracleAlpha,
            _poolId,
            _balancerVaultAddress,
            address(poolTokenMock),
            address(underlierMock),
            address(ePTokenBondMock),
            _timeScale,
            _maturity
        );

        // Test that properties are correctly set
        assertEq(
            ElementFiValueProvider(elementValueProviderAddress)
                .timeUpdateWindow(),
            _oracleUpdateWindow,
            "ElementFi Value Provider incorrect timeUpdateWindow"
        );

        assertEq(
            ElementFiValueProvider(elementValueProviderAddress).maxValidTime(),
            _oracleMaxValidTime,
            "ElementFi Value Provider incorrect maxValidTime"
        );

        assertEq(
            ElementFiValueProvider(elementValueProviderAddress).alpha(),
            _oracleAlpha,
            "ElementFi Value Provider incorrect alpha"
        );

        assertEq(
            ElementFiValueProvider(elementValueProviderAddress).poolId(),
            _poolId,
            "ElementFi Value Provider incorrect poolId"
        );

        assertEq(
            ElementFiValueProvider(elementValueProviderAddress)
                .balancerVaultAddress(),
            _balancerVaultAddress,
            "ElementFi Value Provider incorrect balancerVaultAddress"
        );

        assertEq(
            ElementFiValueProvider(elementValueProviderAddress).poolToken(),
            address(poolTokenMock),
            "ElementFi Value Provider incorrect poolToken"
        );

        assertEq(
            ElementFiValueProvider(elementValueProviderAddress).underlier(),
            address(underlierMock),
            "ElementFi Value Provider incorrect underlier"
        );

        assertEq(
            ElementFiValueProvider(elementValueProviderAddress).ePTokenBond(),
            address(ePTokenBondMock),
            "ElementFi Value Provider incorrect ePTokenBond"
        );

        assertEq(
            ElementFiValueProvider(elementValueProviderAddress).timeScale(),
            _timeScale,
            "ElementFi Value Provider incorrect timeScale"
        );

        assertEq(
            ElementFiValueProvider(elementValueProviderAddress).maturity(),
            _maturity,
            "ElementFi Value Provider incorrect maturity"
        );
    }
}
