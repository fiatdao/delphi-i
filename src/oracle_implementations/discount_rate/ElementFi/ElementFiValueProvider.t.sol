// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import "ds-test/test.sol";

import "src/test/utils/Caller.sol";
import "lib/prb-math/contracts/PRBMathSD59x18.sol";
import {Hevm} from "src/test/utils/Hevm.sol";
import {MockProvider} from "@cleanunicorn/mockprovider/src/MockProvider.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ElementFiValueProvider} from "./ElementFiValueProvider.sol";
import {IVault} from "src/oracle_implementations/discount_rate/ElementFi/IVault.sol";

contract ElementFiValueProviderTest is DSTest {
    Hevm internal hevm = Hevm(DSTest.HEVM_ADDRESS);

    MockProvider internal mockBalancerVault;
    MockProvider internal poolToken;

    MockProvider internal underlierMock;
    MockProvider internal ePTokenBondMock;

    ElementFiValueProvider internal efValueProvider;

    bytes32 internal _poolId =
        bytes32(
            0x6dd0f7c8f4793ed2531c0df4fea8633a21fdcff40002000000000000000000b7
        );
    int256 internal _unitSeconds = 412133793;
    uint256 internal _maturity = 1651275535;
    uint256 internal _timeUpdateWindow = 100; // seconds
    uint256 internal _maxValidTime = 300;
    int256 internal _alpha = 2 * 10**17; // 0.2
    uint256 internal _decimals = 18;

    function setUp() public {
        mockBalancerVault = new MockProvider();
        underlierMock = new MockProvider();
        ePTokenBondMock = new MockProvider();
        poolToken = new MockProvider();

        // Documentation page:
        // https://www.notion.so/fiatdao/FIAT-Interest-Rate-Oracle-System-01092c10abf14e5fb0f1353b3b24a804
        // For extra info about the values used check the examples from the documentation above.
        mockBalancerVault.givenQueryReturnResponse(
            abi.encodeWithSelector(
                IVault.getPoolTokenInfo.selector,
                _poolId,
                IERC20(address(underlierMock))
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

        // The used parameters are: uint256 cash, uint256 managed, int256 lastChangeBlock, address assetManager
        mockBalancerVault.givenQueryReturnResponse(
            abi.encodeWithSelector(
                IVault.getPoolTokenInfo.selector,
                _poolId,
                IERC20(address(ePTokenBondMock))
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

        underlierMock.givenQueryReturnResponse(
            abi.encodeWithSelector(ERC20.decimals.selector),
            MockProvider.ReturnData({success: true, data: abi.encode(_decimals)}),
            false
        );

        ePTokenBondMock.givenQueryReturnResponse(
            abi.encodeWithSelector(ERC20.decimals.selector),
            MockProvider.ReturnData({success: true, data: abi.encode(_decimals)}),
            false
        );

        poolToken.givenQueryReturnResponse(
            abi.encodeWithSelector(ERC20.decimals.selector),
            MockProvider.ReturnData({success: true, data: abi.encode(_decimals)}),
            false
        );

        poolToken.givenQueryReturnResponse(
            abi.encodeWithSelector(IERC20.totalSupply.selector),
            MockProvider.ReturnData({
                success: true,
                data: abi.encode(874253869672828123816)
            }),
            false
        );

        int256 timeScale59x18 = PRBMathSD59x18.div(
            PRBMathSD59x18.SCALE,
            PRBMathSD59x18.fromInt(_unitSeconds)
        );

        efValueProvider = new ElementFiValueProvider(
            // Oracle arguments
            // Time update window
            _timeUpdateWindow,
            // Max valid time
            _maxValidTime,
            // Alpha
            _alpha,
            // Element Fi arguments
            // Pool ID
            _poolId,
            // Address of the balancer vault
            address(mockBalancerVault),
            // pool token address
            address(poolToken),
            // Underlier token address
            address(underlierMock),
            // Principal bond token address
            address(ePTokenBondMock),
            // Time scale in seconds
            timeScale59x18,
            // Maturity timestamp
            _maturity
        );
    }

    function test_deploy() public {
        assertTrue(address(efValueProvider) != address(0));
    }

    function test_check_poolId() public {
        assertEq(efValueProvider.poolId(), _poolId);
    }

    function test_check_balancerVault() public {
        assertEq(
            efValueProvider.balancerVaultAddress(),
            address(mockBalancerVault)
        );
    }

    function test_check_poolToken() public {
        assertEq(efValueProvider.poolToken(), address(poolToken));
    }

    function test_check_poolTokenDecimals() public {
        assertEq(efValueProvider.poolTokenDecimals(), _decimals);
    }

    function test_check_underlier() public {
        assertEq(efValueProvider.underlier(), address(underlierMock));
    }

    function test_check_underlierDecimals() public {
        assertEq(efValueProvider.underlierDecimals(), _decimals);
    }

    function test_check_ePTokenBond() public {
        assertEq(efValueProvider.ePTokenBond(), address(ePTokenBondMock));
    }

    function test_check_ePTokenBondDecimals() public {
        assertEq(efValueProvider.ePTokenBondDecimals(), _decimals);
    }

    function test_check_timeScale() public {
        int256 timeScale59x18 = PRBMathSD59x18.div(
            PRBMathSD59x18.SCALE,
            PRBMathSD59x18.fromInt(_unitSeconds)
        );

        assertEq(efValueProvider.timeScale(), timeScale59x18);
    }

    function test_check_maturity() public {
        assertEq(efValueProvider.maturity(), _maturity);
    }

    function test_getValue() public {
        // Computed value based on the parameters that are sent via the mock provider
        int256 computedExpectedValue = 4583021729;

        int256 value = efValueProvider.getValue();

        assertTrue(value == computedExpectedValue);
    }

    function testFail_getValue_revertsOnOrAfterMaturityDate() public
    {
        hevm.warp(efValueProvider.maturity());
        efValueProvider.getValue();
    }
}
