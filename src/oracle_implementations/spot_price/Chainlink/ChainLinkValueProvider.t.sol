// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import "ds-test/test.sol";

import "src/test/utils/Caller.sol";
import {Hevm} from "src/test/utils/Hevm.sol";
import {MockProvider} from "@cleanunicorn/mockprovider/src/MockProvider.sol";

import {IChainlinkAggregatorV3Interface} from "src/oracle_implementations/spot_price/Chainlink/ChainlinkAggregatorV3Interface.sol";
import {ChainLinkValueProvider} from "src/oracle_implementations/spot_price/Chainlink/ChainLinkValueProvider.sol";

contract ChainLinkValueProviderTest is DSTest {
    Hevm internal hevm = Hevm(DSTest.HEVM_ADDRESS);

    MockProvider internal mockChainlinkAggregator;

    ChainLinkValueProvider internal chainlinkVP;

    uint256 internal _timeUpdateWindow = 100; // seconds
    uint256 internal _maxValidTime = 300;
    int256 internal _alpha = 2 * 10**17; // 0.2

    function setUp() public {
        mockChainlinkAggregator = new MockProvider();

        // Values taken from https://etherscan.io/address/0x8fffffd4afb6115b954bd326cbe7b4ba576818f6
        // At block: 14041337
        mockChainlinkAggregator.givenQueryReturnResponse(
            abi.encodeWithSelector(
                IChainlinkAggregatorV3Interface.latestRoundData.selector
            ),
            MockProvider.ReturnData({
                success: true,
                data: abi.encode(
                    uint80(36893488147419103548), // roundId
                    int256(100016965), // answer
                    uint256(1642615905), // startedAt
                    uint256(1642615905), // updatedAt
                    uint80(36893488147419103548) // answeredInRound
                )
            }),
            false
        );

        mockChainlinkAggregator.givenQueryReturnResponse(
            abi.encodeWithSelector(
                IChainlinkAggregatorV3Interface.decimals.selector
            ),
            MockProvider.ReturnData({success: true, data: abi.encode(8)}),
            false
        );

        mockChainlinkAggregator.givenQueryReturnResponse(
            abi.encodeWithSelector(
                IChainlinkAggregatorV3Interface.description.selector
            ),
            MockProvider.ReturnData({
                success: true,
                data: abi.encode("USDC / USD")
            }),
            false
        );

        chainlinkVP = new ChainLinkValueProvider(
            // Oracle arguments
            // Time update window
            _timeUpdateWindow,
            // Max valid time
            _maxValidTime,
            // Alpha
            _alpha,
            // Chainlink arguments
            address(mockChainlinkAggregator)
        );
    }

    function test_deploy() public {
        assertTrue(address(chainlinkVP) != address(0));
    }

    function testFail_deploy_ShouldFailWithUnsupportedDecimals() public {
        MockProvider unsupportedDecimalsMP = new MockProvider();
        unsupportedDecimalsMP.givenQueryReturnResponse(
            abi.encodeWithSelector(
                IChainlinkAggregatorV3Interface.decimals.selector
            ),
            MockProvider.ReturnData({
                success: true,
                data: abi.encode(uint8(19))
            }),
            false
        );

        ChainLinkValueProvider vp = new ChainLinkValueProvider(
            // Oracle arguments
            // Time update window
            _timeUpdateWindow,
            // Max valid time
            _maxValidTime,
            // Alpha
            _alpha,
            // Chainlink arguments
            address(unsupportedDecimalsMP)
        );

        assertTrue(address(vp) == address(0));
    }

    function test_getValue() public {
        // Expected value is the value sent by the mock provider in 10**18 precision
        int256 expectedValue = 100016965 * 1e10;
        // Computed value based on the parameters that are sent via the mock provider
        int256 value = chainlinkVP.getValue();

        assertTrue(value == expectedValue);
    }

    function test_description() public {
        string memory expectedDescription = "USDC / USD";
        string memory desc = chainlinkVP.description();
        assertTrue(
            keccak256(abi.encodePacked(desc)) ==
                keccak256(abi.encodePacked(expectedDescription))
        );
    }

    function test_check_underlierDecimals() public {
        assertEq(chainlinkVP.underlierDecimals(), uint256(8));
    }

    function test_check_chainlinkAggregatorAddress() public {
        assertEq(
            chainlinkVP.chainlinkAggregatorAddress(),
            address(mockChainlinkAggregator)
        );
    }
}
