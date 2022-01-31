// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import "src/valueprovider/utils/Convert.sol";
import {IValueProvider} from "src/valueprovider/IValueProvider.sol";
import {IChainlinkAggregatorV3Interface} from "src/valueprovider/SpotPrice/ChainlinkAggregatorV3Interface.sol";

contract ChainLinkValueProvider is IValueProvider, Convert {
    uint8 public immutable underlierDecimals;
    address public underlierAddress;
    address public chainlinkAggregatorAddress;

    /// @notice                             Constructs the Value provider contracts with the needed Chainlink.
    /// @param chainlinkAggregatorAddress_  Address of the deployed chainlink aggregator contract.
    constructor(address chainlinkAggregatorAddress_) {
        chainlinkAggregatorAddress = chainlinkAggregatorAddress_;
        underlierDecimals = IChainlinkAggregatorV3Interface(chainlinkAggregatorAddress).decimals();
    }

    /// @notice Retrieves the price from the chainlink aggregator
    /// @return result The result as an signed 59.18-decimal fixed-point number.
    function value() external view override(IValueProvider) returns (int256) {
        // The returned annual rate is in 1e9 precision so we need to convert it to 1e18 precision.
        (, int256 answer, , , ) = IChainlinkAggregatorV3Interface(chainlinkAggregatorAddress).latestRoundData();

        return convert(answer, underlierDecimals, 18);
    }

    /// @notice returns the description of the chainlink aggregator the proxy points to.
    function description() external view returns (string memory) {
        return
            IChainlinkAggregatorV3Interface(chainlinkAggregatorAddress).description();
    }
}
