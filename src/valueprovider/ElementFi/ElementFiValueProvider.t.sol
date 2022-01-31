// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import "ds-test/test.sol";

import "src/test/utils/Caller.sol";
import {Hevm} from "src/test/utils/Hevm.sol";
import {MockProvider} from "src/test/utils/MockProvider.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ElementFiValueProvider} from "./ElementFiValueProvider.sol";
import {IVault} from "src/valueprovider/ElementFi/IVault.sol";

contract ElementFiValueProviderTest is DSTest {
    Hevm internal hevm = Hevm(DSTest.HEVM_ADDRESS);

    MockProvider internal mockBalancerVault;
    MockProvider internal poolToken;

    ElementFiValueProvider internal efValueProvider;

    bytes32 internal _poolId =
        0x10a2f8bd81ee2898d7ed18fb8f114034a549fa59000200000000000000000090;
    uint256 internal _timeToMaturity = 1651275535;
    address internal _underlier = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address internal _ePTokenBond = 0x8a2228705ec979961F0e16df311dEbcf097A2766;
    uint256 internal _unitSeconds = 1000355378;

    function setUp() public {
        mockBalancerVault = new MockProvider();

        // Documentation page:
        // https://www.notion.so/fiatdao/FIAT-Interest-Rate-Oracle-System-01092c10abf14e5fb0f1353b3b24a804
        // For extra info about the values used check the examples from the documentation above.
        mockBalancerVault.givenQueryReturnResponse(
            // Used Parameters are: pool id, underlier address
            abi.encodeWithSelector(
                IVault.getPoolTokenInfo.selector,
                bytes32(
                    0x6dd0f7c8f4793ed2531c0df4fea8633a21fdcff40002000000000000000000b7
                ),
                IERC20(address(0x285328906D0D33cb757c1E471F5e2176683247c2))
            ),
            MockProvider.ReturnData({
                success: true,
                data: abi.encode(
                    uint256(663426072118149531985),
                    uint256(0),
                    uint256(0),
                    address(0)
                )
            }),
            false
        );

        // The used parameters are: uint256 cash, uint256 managed, int256 lastChangeBlock, address assetManager
        // for more info check the IVault getPoolTokenInfo description
        mockBalancerVault.givenQueryReturnResponse(
            abi.encodeWithSelector(
                IVault.getPoolTokenInfo.selector,
                bytes32(
                    0x6dd0f7c8f4793ed2531c0df4fea8633a21fdcff40002000000000000000000b7
                ),
                IERC20(address(0xc4AD29ba4B3c580e6D59105FFf484999997675Ff))
            ),
            MockProvider.ReturnData({
                success: true,
                data: abi.encode(
                    uint256(232574802191012296969),
                    uint256(0),
                    uint256(0),
                    address(0)
                )
            }),
            false
        );

        poolToken = new MockProvider();
        poolToken.givenQueryReturnResponse(
            abi.encodeWithSelector(IERC20.totalSupply.selector),
            MockProvider.ReturnData({
                success: true,
                data: abi.encode(uint256(874253869672828123816))
            }),
            false
        );

        efValueProvider = new ElementFiValueProvider(
            // Pool ID
            0x6dd0f7c8f4793ed2531c0df4fea8633a21fdcff40002000000000000000000b7,
            // Address of the balancer vault
            address(mockBalancerVault),
            // pool token address
            address(poolToken),
            // pool token decimals
            18,
            // Underlier token address
            0xc4AD29ba4B3c580e6D59105FFf484999997675Ff,
            // Underlier decimal format
            18,
            // Principal bond token address
            0x285328906D0D33cb757c1E471F5e2176683247c2,
            // Principal bond decimal format
            18,
            // Time scale in seconds
            412133793
        );
    }

    function test_deploy() public {
        assertTrue(address(efValueProvider) != address(0));
    }

    function test_check_poolId() public {
        assertEq(efValueProvider.poolId(), _poolId);
    }

    function test_check_balancerVault() public {
        assertEq(efValueProvider.balancerVault(), address(mockBalancerVault));
    }

    function test_check_timeToMaturity() public {
        assertEq(efValueProvider.timeToMaturity(), _timeToMaturity);
    }

    function test_check_underlier() public {
        assertEq(efValueProvider.underlier(), _underlier);
    }

    function test_check_ePTokenBond() public {
        assertEq(efValueProvider.ePTokenBond(), _ePTokenBond);
    }

    function test_check_unitSeconds() public {
        assertEq(efValueProvider.unitSeconds(), _unitSeconds);
    }

    function test_GetValue() public {
        // Computed value based on the parameters that are sent via the mock provider
        int256 computedExpectedValue = 4583021729;

        int256 value = efValueProvider.value();

        assertTrue(value == computedExpectedValue);
    }
}
