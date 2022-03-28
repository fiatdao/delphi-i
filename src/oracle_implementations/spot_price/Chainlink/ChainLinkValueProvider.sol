// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import {Oracle} from "../../../oracle/Oracle.sol";
import {Convert} from "../../discount_rate/utils/Convert.sol";
import {IChainlinkAggregatorV3Interface} from "./ChainlinkAggregatorV3Interface.sol";

contract ChainLinkValueProvider is Oracle, Convert {
    uint8 public immutable underlierDecimals;
    address public chainlinkAggregatorAddress;

    /// @notice Constructs the Value provider contracts with the needed Chainlink.
    /// @param timeUpdateWindow_ Minimum time between updates of the value
    /// @param chainlinkAggregatorAddress_ Address of the deployed chainlink aggregator contract.
    constructor(
        // Oracle parameters
        uint256 timeUpdateWindow_,
        // Chainlink specific parameter
        address chainlinkAggregatorAddress_
    ) Oracle(timeUpdateWindow_) {
        chainlinkAggregatorAddress = chainlinkAggregatorAddress_;
        underlierDecimals = IChainlinkAggregatorV3Interface(
            chainlinkAggregatorAddress_
        ).decimals();
    }

    /// @notice Retrieves the price from the chainlink aggregator
    /// @return result The result as an signed 59.18-decimal fixed-point number.
    function getValue() external view override(Oracle) returns (int256) {
        // Convert the annual rate to 1e18 precision.
        (, int256 answer, , , ) = IChainlinkAggregatorV3Interface(
            chainlinkAggregatorAddress
        ).latestRoundData();

        return convert(answer, underlierDecimals, 18);
    }

    /// @notice returns the description of the chainlink aggregator the proxy points to.
    function description() external view returns (string memory) {
        return
            IChainlinkAggregatorV3Interface(chainlinkAggregatorAddress)
                .description();
    }
}
