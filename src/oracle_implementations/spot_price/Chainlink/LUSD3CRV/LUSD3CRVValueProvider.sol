// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import {Oracle} from "../../../../oracle/Oracle.sol";
import {Convert} from "../../../discount_rate/utils/Convert.sol";
import {IChainlinkAggregatorV3Interface} from "../ChainlinkAggregatorV3Interface.sol";

contract LUSD3CRVValueProvider is Oracle, Convert {
    uint256 public immutable decimalsLUSD;
    uint256 public immutable decimalsUSDC;
    uint256 public immutable decimalsDAI;
    uint256 public immutable decimalsUSDT;

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
        address chainlinkLUSD_,
        address chainlinkUSDC_,
        address chainlinkDAI_,
        address chainlinkUSDT_
    ) Oracle(timeUpdateWindow_) {
        // Init LUSD chainlink properties
        chainlinkLUSD = chainlinkLUSD_;
        decimalsLUSD = IChainlinkAggregatorV3Interface(chainlinkLUSD_)
            .decimals();

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
        // Get the LUSD price and convert it to 59.18-decimal fixed-point format
        (, int256 lusdPrice, , , ) = IChainlinkAggregatorV3Interface(
            chainlinkLUSD
        ).latestRoundData();
        int256 lusd59x18 = convert(lusdPrice, decimalsLUSD, 18);

        // Get the USDC price and convert it to 59.18-decimal fixed-point format
        (, int256 usdcPrice, , , ) = IChainlinkAggregatorV3Interface(
            chainlinkUSDC
        ).latestRoundData();
        int256 usdc59x18 = convert(usdcPrice, decimalsUSDC, 18);

        // Get the DAI price and convert it to 59.18-decimal fixed-point format
        (, int256 daiPrice, , , ) = IChainlinkAggregatorV3Interface(
            chainlinkDAI
        ).latestRoundData();
        int256 dai59x18 = convert(daiPrice, decimalsDAI, 18);

        // Get the LUSD price and convert it to 59.18-decimal fixed-point format
        (, int256 usdtPrice, , , ) = IChainlinkAggregatorV3Interface(
            chainlinkUSDT
        ).latestRoundData();

        int256 usdt59x18 = convert(usdtPrice, decimalsUSDT, 18);

        // The weights are: 50% LUSD, 16.(6)% USDC, 16.(6)% DAI, 16.(6)% USDT
        return (lusd59x18 * 3 + usdc59x18 + dai59x18 + usdt59x18) / 6;
    }

    /// @notice returns the description of the chainlink aggregator the proxy points to.
    function description() external pure returns (string memory) {
        return "LUSD3CRV";
    }
}
