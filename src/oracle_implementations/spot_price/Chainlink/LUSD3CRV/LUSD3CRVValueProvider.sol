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
    uint256 public immutable decimals3Pool;
    uint256 public immutable decimalsLUSD3Pool;
    uint256 public immutable decimalsUSDC;
    uint256 public immutable decimalsDAI;
    uint256 public immutable decimalsUSDT;
    uint256 public immutable decimalsLUSD;

    // DAI/USDC/USDT pool
    address public immutable curve3Pool;
    address public immutable curveLUSD3Pool;

    address public immutable chainlinkLUSD;
    address public immutable chainlinkUSDC;
    address public immutable chainlinkDAI;
    address public immutable chainlinkUSDT;

    /// @notice Constructs the Value provider contracts with the needed Chainlink.
    /// @param timeUpdateWindow_ Minimum time between updates of the value
    constructor(
        // Oracle parameters
        uint256 timeUpdateWindow_,
        // Chainlink specific parameter
        address curve3Pool_,
        address curveLUSD3Pool_,
        address chainlinkLUSD_,
        address chainlinkUSDC_,
        address chainlinkDAI_,
        address chainlinkUSDT_
    ) Oracle(timeUpdateWindow_) {
        // Init the 3curve Pool
        curve3Pool = curve3Pool_;
        decimals3Pool = ICurvePool(curve3Pool_).decimals();

        // Init the LUSD3curve Pool
        curveLUSD3Pool = curveLUSD3Pool_;
        decimalsLUSD3Pool = ICurvePool(curveLUSD3Pool_).decimals();

        // Init USDC chainlink properties
        chainlinkUSDC = chainlinkUSDC_;
        decimalsUSDC = IChainlinkAggregatorV3Interface(chainlinkUSDC_)
            .decimals();

        // Init LUSD chainlink properties
        chainlinkLUSD = chainlinkLUSD_;
        decimalsLUSD = IChainlinkAggregatorV3Interface(chainlinkLUSD_)
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
    /// @return result The result as an signed 59.18-decimal fixed-point number
    /// @dev The price is calculated following the steps described in this document
    /// https://news.curve.fi/chainlink-oracles-and-curve-pools/
    function getValue() external view override(Oracle) returns (int256) {
        // Get the USDC price and convert it to 59.18-decimal fixed-point format
        (, int256 usdcPrice, , , ) = IChainlinkAggregatorV3Interface(
            chainlinkUSDC
        ).latestRoundData();

        // Compute the min price as we fetch data
        int256 min3pTokenPrice59x18 = convert(usdcPrice, decimalsUSDC, 18);

        // Get the DAI price and convert it to 59.18-decimal fixed-point format
        (, int256 daiPrice, , , ) = IChainlinkAggregatorV3Interface(
            chainlinkDAI
        ).latestRoundData();
        // Update the min price as we fetch data
        min3pTokenPrice59x18 = min(
            min3pTokenPrice59x18,
            convert(daiPrice, decimalsDAI, 18)
        );

        // Get the USDT price and convert it to 59.18-decimal fixed-point format
        (, int256 usdtPrice, , , ) = IChainlinkAggregatorV3Interface(
            chainlinkUSDT
        ).latestRoundData();
        // Update the min price as we fetch data
        min3pTokenPrice59x18 = min(
            min3pTokenPrice59x18,
            convert(usdtPrice, decimalsUSDT, 18)
        );

        // Fetch the virtual price for the 3pool
        int256 vCurve3Price59x18 = convert(
            int256(ICurvePool(curve3Pool).get_virtual_price()),
            decimals3Pool,
            18
        );
        int256 curve3Price59x18 = PRBMathSD59x18.mul(
            vCurve3Price59x18,
            min3pTokenPrice59x18
        );

        // Get the LUSD price and convert it to 59.18-decimal fixed-point format
        (, int256 lusdPrice, , , ) = IChainlinkAggregatorV3Interface(
            chainlinkLUSD
        ).latestRoundData();
        int256 lusd59x18 = convert(lusdPrice, decimalsLUSD, 18);

        int256 vLUSD3Price59x18 = convert(
            int256(ICurvePool(curveLUSD3Pool).get_virtual_price()),
            decimalsLUSD3Pool,
            18
        );

        return
            PRBMathSD59x18.mul(
                vLUSD3Price59x18,
                min(curve3Price59x18, lusd59x18)
            );
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
