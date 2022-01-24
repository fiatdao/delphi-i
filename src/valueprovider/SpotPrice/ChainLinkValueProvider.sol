// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import "src/utils/Math.sol";
import {IValueProvider} from "src/valueprovider/IValueProvider.sol";
import {IChainlinkAggregatorV3Interface} from "src/valueprovider/SpotPrice/ChainlinkAggregatorV3Interface.sol";

contract ChainLinkValueProvider is IValueProvider {
    uint256 private immutable _underlierDecimals;
    address private _underlierAddress;
    IChainlinkAggregatorV3Interface private _chainlinkAggregator;

    /// @notice                             Constructs the Value provider contracts with the needed Chainlink.
    /// @param chainlinkAggregatorAddress_  Address of the deployed chainlink aggregator contract.
    constructor(address chainlinkAggregatorAddress_) {
        _chainlinkAggregator = IChainlinkAggregatorV3Interface(
            chainlinkAggregatorAddress_
        );
        
        _underlierDecimals =  uint256(_chainlinkAggregator.decimals());
    }

    /// @notice Retrieves the price from the chainlink aggregator
    /// @return result The result as an signed 59.18-decimal fixed-point number.
    function value() external view override(IValueProvider) returns (int256) {
        // The returned annual rate is in 1e9 precision so we need to convert it to 1e18 precision.
        (, int256 answer, , , ) = _chainlinkAggregator.latestRoundData();

        return convert(answer,_underlierDecimals,18);
    }

    /// @notice returns the description of the chainlink aggregator the proxy points to.
    function description() external view returns (string memory) {
        return _chainlinkAggregator.description();
    }
}
