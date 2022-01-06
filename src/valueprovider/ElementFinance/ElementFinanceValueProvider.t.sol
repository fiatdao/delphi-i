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

    function setUp() public {
        mockBalancerVault = new MockProvider();

        // Values taken from a Element Curve Pool Contract deployed at
        // https://etherscan.io/address/0x10a2F8bd81Ee2898D7eD18fb8f114034a549FA59
        // block: 13951463
        mockBalancerVault.givenQueryReturnResponse(
            // Used Parameters are: pool id, underlier address
            abi.encodeWithSelector(
                IVault.getPoolTokenInfo.selector,
                bytes32(
                    0x10a2f8bd81ee2898d7ed18fb8f114034a549fa59000200000000000000000090
                ),
                IERC20(address(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48))
            ),
            MockProvider.ReturnData({
                success: true,
                data: abi.encode(
                    uint256(32149978535139),
                    uint256(0),
                    uint256(13945348),
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
                    0x10a2f8bd81ee2898d7ed18fb8f114034a549fa59000200000000000000000090
                ),
                IERC20(address(0x8a2228705ec979961F0e16df311dEbcf097A2766))
            ),
            MockProvider.ReturnData({
                success: true,
                data: abi.encode(
                    uint256(20296393428881),
                    uint256(0),
                    uint256(13945348),
                    address(0)
                )
            }),
            false
        );

        efValueProvider = new ElementFinanceValueProvider(
            // Pool ID
            0x10a2f8bd81ee2898d7ed18fb8f114034a549fa59000200000000000000000090,
            // Address of the balancer vault
            address(mockBalancerVault),
            // Underlier token address
            0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48,
            // Principal bond token address
            0x8a2228705ec979961F0e16df311dEbcf097A2766,
            // Time scale in seconds
            779456714
        );
    }

    function test_deploy() public {
        assertTrue(address(efValueProvider) != address(0));
    }

    function test_GetValue() public {
        // Computed value based on the parameters that are sent via the mock provider
        int256 computedExpectedValue = -590114329;
        int256 value = efValueProvider.value();

        assertTrue(value == computedExpectedValue);
    }
}
