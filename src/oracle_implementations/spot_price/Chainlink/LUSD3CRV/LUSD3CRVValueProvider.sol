// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;
import {Oracle} from "../../../../oracle/Oracle.sol";
import {Convert} from "../../../discount_rate/utils/Convert.sol";
import {IChainlinkAggregatorV3Interface} from "../ChainlinkAggregatorV3Interface.sol";
import {ICurvePool} from "./ICurvePool.sol";
import "prb-math/contracts/PRBMathSD59x18.sol";

/// @notice Oracle implementation for Curve LP tokens via Chainlink Oracles
/// as described in this guide: https://news.curve.fi/chainlink-oracles-and-curve-pools/
contract LUSD3CRVValueProvider is Oracle, Convert {
    /// @notice Emitted when a pool with unsupported decimals is used
    error LUSD3CRVValueProvider__constructor_InvalidPoolDecimals(address pool);

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

    /// @notice Constructs the Value provider contracts with the needed Chainlink data feeds
    /// @param timeUpdateWindow_ Minimum time between updates of the value
    /// @param curve3Pool_ Address of the  Curve 3pool
    /// @param curveLUSD3Pool_ Address of the Curve LUSD-3pool pool
    /// @param chainlinkLUSD_ Address of the LUSD chainlink data feed
    /// @param chainlinkUSDC_ Address of the USDC chainlink data feed
    /// @param chainlinkDAI_ Address of the DAI chainlink data feed
    /// @param chainlinkUSDT_ Address of the USDT chainlink data feed
    constructor(
        // Oracle parameters
        uint256 timeUpdateWindow_,
        // Chainlink specific parameters
        address curve3Pool_,
        address curveLUSD3Pool_,
        address chainlinkLUSD_,
        address chainlinkUSDC_,
        address chainlinkDAI_,
        address chainlinkUSDT_
    ) Oracle(timeUpdateWindow_) {
        if (ICurvePool(curve3Pool_).decimals() != 18) {
            revert LUSD3CRVValueProvider__constructor_InvalidPoolDecimals(
                curve3Pool_
            );
        }
        // Init the Curve 3pool
        curve3Pool = curve3Pool_;

        if (ICurvePool(curveLUSD3Pool_).decimals() != 18) {
            revert LUSD3CRVValueProvider__constructor_InvalidPoolDecimals(
                curveLUSD3Pool_
            );
        }
        // Init the Curve LUSD-3pool
        curveLUSD3Pool = curveLUSD3Pool_;

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

    /// @notice The price is calculated following the steps described in this document
    /// https://news.curve.fi/chainlink-oracles-and-curve-pools/
    /// @return result The result as an signed 59.18-decimal fixed-point number
    function getValue() external view override(Oracle) returns (int256) {
        // Get the USDC price and convert it to 59.18-decimal fixed-point format
        (, int256 usdcPrice, , , ) = IChainlinkAggregatorV3Interface(
            chainlinkUSDC
        ).latestRoundData();

        // Minimum token prices needed in the formula
        int256 minTokenPrice59x18;

        // Init min price with the first token price
        minTokenPrice59x18 = convert(usdcPrice, decimalsUSDC, 18);

        // Get the DAI price and convert it to 59.18-decimal fixed-point format
        (, int256 daiPrice, , , ) = IChainlinkAggregatorV3Interface(
            chainlinkDAI
        ).latestRoundData();
        // Update the min price as we fetch data
        minTokenPrice59x18 = min(
            minTokenPrice59x18,
            convert(daiPrice, decimalsDAI, 18)
        );

        // Get the USDT price and convert it to 59.18-decimal fixed-point format
        (, int256 usdtPrice, , , ) = IChainlinkAggregatorV3Interface(
            chainlinkUSDT
        ).latestRoundData();
        // Update the min price as we fetch data
        minTokenPrice59x18 = min(
            minTokenPrice59x18,
            convert(usdtPrice, decimalsUSDT, 18)
        );

        // Calculate the price the Curve 3pool lpToken
        int256 curve3lpTokenPrice59x18 = PRBMathSD59x18.mul(
            int256(ICurvePool(curve3Pool).get_virtual_price()),
            minTokenPrice59x18
        );

        // Get the LUSD price and convert it to 59.18-decimal fixed-point format
        (, int256 lusdPrice, , , ) = IChainlinkAggregatorV3Interface(
            chainlinkLUSD
        ).latestRoundData();
        int256 lusd59x18 = convert(lusdPrice, decimalsLUSD, 18);

        // Compute the final price for the Curve LUSD-3pool
        return
            PRBMathSD59x18.mul(
                int256(ICurvePool(curveLUSD3Pool).get_virtual_price()),
                min(curve3lpTokenPrice59x18, lusd59x18)
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
