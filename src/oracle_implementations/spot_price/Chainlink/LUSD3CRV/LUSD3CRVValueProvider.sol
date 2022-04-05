// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import {Oracle} from "../../../../oracle/Oracle.sol";
import {Convert} from "../../../discount_rate/utils/Convert.sol";
import {IChainlinkAggregatorV3Interface} from "../ChainlinkAggregatorV3Interface.sol";
import "prb-math/contracts/PRBMathSD59x18.sol";

interface ICurvePool {
    function get_virtual_price() external view returns (uint256);

    function decimals() external view returns (uint256);
}

/// @notice Oracle implementation for Curve Pool token via Chainlink Oracles
/// as described in this guide: https://news.curve.fi/chainlink-oracles-and-curve-pools/
contract LUSD3CRVValueProvider is Oracle, Convert {
    uint256 public immutable decimalsPoolToken;
    uint256 public immutable decimalsUSDC;
    uint256 public immutable decimalsDAI;
    uint256 public immutable decimalsUSDT;

    address public immutable curvePool;
    address public immutable chainlinkUSDC;
    address public immutable chainlinkDAI;
    address public immutable chainlinkUSDT;

    /// @notice Constructs the Value provider contracts with the needed Chainlink.
    /// @param timeUpdateWindow_ Minimum time between updates of the value
    constructor(
        // Oracle parameters
        uint256 timeUpdateWindow_,
        // Chainlink specific parameter
        address curvePool_,
        address chainlinkUSDC_,
        address chainlinkDAI_,
        address chainlinkUSDT_
    ) Oracle(timeUpdateWindow_) {
        // Init the curve Pool
        curvePool = curvePool_;

        decimalsPoolToken = ICurvePool(curvePool_).decimals();

        // Init USDC chainlink properties
        chainlinkUSDC = chainlinkUSDC_;
        decimalsUSDC = IChainlinkAggregatorV3Interface(chainlinkUSDC_)
            .decimals();

        // Init DAI chainlink properties
        chainlinkDAI = chainlinkDAI_;
        decimalsDAI = IChainlinkAggregatorV3Interface(chainlinkDAI_).decimals();

        // Init USDT chainlink properties
        chainlinkUSDT = chainlinkUSDT_;
        decimalsUSDT = IChainlinkAggregatorV3Interface(chainlinkUSDT_)
            .decimals();
    }

    /// @notice Retrieves the price from the chainlink aggregator
    /// @return result The result as an signed 59.18-decimal fixed-point number.
    function getValue() external view override(Oracle) returns (int256) {
        // Get the USDC price and convert it to 59.18-decimal fixed-point format
        (, int256 usdcPrice, , , ) = IChainlinkAggregatorV3Interface(
            chainlinkUSDC
        ).latestRoundData();

        // Compute the min price as we fetch data
        int256 minPrice59x18 = convert(usdcPrice, decimalsUSDC, 18);

        // Get the DAI price and convert it to 59.18-decimal fixed-point format
        (, int256 daiPrice, , , ) = IChainlinkAggregatorV3Interface(
            chainlinkDAI
        ).latestRoundData();
        minPrice59x18 = min(minPrice59x18, convert(daiPrice, decimalsDAI, 18));

        // Get the LUSD price and convert it to 59.18-decimal fixed-point format
        (, int256 usdtPrice, , , ) = IChainlinkAggregatorV3Interface(
            chainlinkUSDT
        ).latestRoundData();
        minPrice59x18 = min(
            minPrice59x18,
            convert(usdtPrice, decimalsUSDT, 18)
        );

        // Fetch the virtual price for the LP token
        int256 virtualPrice58x18 = convert(
            int256(ICurvePool(curvePool).get_virtual_price()),
            decimalsPoolToken,
            18
        );

        return PRBMathSD59x18.mul(virtualPrice58x18, minPrice59x18);
    }

    /// @notice Returns the description of the value provider.
    function description() external pure returns (string memory) {
        return "LUSD3CRV";
    }

    /// @notice Helper math min function
    function min(int256 a, int256 b) internal pure returns (int256) {
        return a < b ? a : b;
    }
}
