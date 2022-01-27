// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import {IValueProvider} from "src/valueprovider/IValueProvider.sol";

import {IChainlinkAggregatorV3Interface} from "src/valueprovider/SpotPrice/ChainlinkAggregatorV3Interface.sol";

error ChainLinkValueProvider__constructor_unsupportedUnderlierDecimalFormat(
    uint8 underlierDecimals
);

contract ChainLinkValueProvider is IValueProvider {
    int256 public immutable underlierDecimalsConversion;

    address public immutable chainlinkAggregator;

    /// @notice                         Constructs the Value provider contracts with the needed Chainlink.
    /// @param chainlinkAggregator_     Address of the deployed chainlink aggregator contract.
    constructor(address chainlinkAggregator_) {
        chainlinkAggregator = chainlinkAggregator_;
        uint8 underlierDecimals = IChainlinkAggregatorV3Interface(chainlinkAggregator_).decimals();
        if (underlierDecimals > 18)
            revert ChainLinkValueProvider__constructor_unsupportedUnderlierDecimalFormat(
                underlierDecimals
            );

        underlierDecimalsConversion = int256(10**(18 - underlierDecimals));
    }

    /// @notice Retrieves the price from the chainlink aggregator
    /// @return result The result as an signed 59.18-decimal fixed-point number.
    function value() external view override(IValueProvider) returns (int256) {
        // The returned annual rate is in 1e9 precision so we need to convert it to 1e18 precision.
        (, int256 answer, , , ) = IChainlinkAggregatorV3Interface(chainlinkAggregator).latestRoundData();
        return answer * underlierDecimalsConversion;
    }

    /// @notice returns the description of the chainlink aggregator the proxy points to.
    function description() external view returns (string memory) {
        return IChainlinkAggregatorV3Interface(chainlinkAggregator).description();
    }
}
