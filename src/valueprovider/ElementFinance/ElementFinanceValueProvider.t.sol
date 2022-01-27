// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import "ds-test/test.sol";

import "src/test/utils/Caller.sol";
import {Hevm} from "src/test/utils/Hevm.sol";
import {MockProvider} from "src/test/utils/MockProvider.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ElementFinanceValueProvider} from "./ElementFinanceValueProvider.sol";
import {IVault} from "src/valueprovider/ElementFinance/IVault.sol";

contract ElementFinanceValueProviderTest is DSTest {
    Hevm internal hevm = Hevm(DSTest.HEVM_ADDRESS);

    MockProvider internal mockBalancerVault;

    ElementFinanceValueProvider internal efValueProvider;

    bytes32 internal _poolId = 0x10a2f8bd81ee2898d7ed18fb8f114034a549fa59000200000000000000000090;
    uint256 internal _timeToMaturity = 1651275535;
    address internal _underlier = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address internal _ePTokenBond = 0x8a2228705ec979961F0e16df311dEbcf097A2766;
    uint256 internal _unitSeconds = 1000355378;

    function setUp() public {
        mockBalancerVault = new MockProvider();

        // Documentation page:
        // https://www.notion.so/fiatdao/FIAT-Interest-Rate-Oracle-System-01092c10abf14e5fb0f1353b3b24a804
        // For extra info about the values used check the second example from the documentation above.
        mockBalancerVault.givenQueryReturnResponse(
            // Used Parameters are: pool id, underlier address
            abi.encodeWithSelector(
                IVault.getPoolTokenInfo.selector,
                bytes32(
                    _poolId
                ),
                IERC20(_underlier)
            ),
            MockProvider.ReturnData({
                success: true,
                data: abi.encode(
                    uint256(458783042838683314781124),
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
                    _poolId
                ),
                IERC20(address(_ePTokenBond))
            ),
            MockProvider.ReturnData({
                success: true,
                data: abi.encode(
                    uint256(386200838116957287987844),
                    uint256(0),
                    uint256(0),
                    address(0)
                )
            }),
            false
        );

        efValueProvider = new ElementFinanceValueProvider(
            // Pool ID
            _poolId,
            // Address of the balancer vault
            address(mockBalancerVault),
            // Underlier token address
            _underlier,
            // Principal bond token address
            _ePTokenBond,
            // Timestamp to maturity,
            _timeToMaturity,
            // Time scale in seconds
            _unitSeconds
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
        int256 computedExpectedValue = 31000116467775202;
        hevm.warp(1642067742);

        int256 value = efValueProvider.value();

        assertTrue(value == computedExpectedValue);
    }
}
