// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import {IChainlinkAggregatorV3Interface} from "src/oracle_implementations/spot_price/Chainlink/ChainlinkAggregatorV3Interface.sol";

import {Oracle} from "src/oracle/Oracle.sol";

error ChainLinkValueProvider__unsuportedUnderlierDecimalFormat(
    uint8 underlierDecimals
);

contract ChainLinkValueProvider is Oracle {
    int256 private immutable _underlierDecimalsConversion;

    address internal _underlierAddress;
    IChainlinkAggregatorV3Interface internal _chainlinkAggregator;

    /// @notice                             Constructs the Value provider contracts with the needed Chainlink.
    /// @param chainlinkAggregatorAddress_  Address of the deployed chainlink aggregator contract.
    constructor(
        // Oracle parameters
        uint256 timeUpdateWindow_,
        uint256 maxValidTime_,
        int256 alpha_,
        //
        address chainlinkAggregatorAddress_
    ) Oracle(timeUpdateWindow_, maxValidTime_, alpha_) {
        _chainlinkAggregator = IChainlinkAggregatorV3Interface(
            chainlinkAggregatorAddress_
        );
        uint8 underlierDecimals = _chainlinkAggregator.decimals();
        if (underlierDecimals > 18)
            revert ChainLinkValueProvider__unsuportedUnderlierDecimalFormat(
                underlierDecimals
            );

        _underlierDecimalsConversion = int256(10**(18 - underlierDecimals));
    }

    /// @notice Retrieves the price from the chainlink aggregator
    /// @return result The result as an signed 59.18-decimal fixed-point number.
    function getValue() external view override(Oracle) returns (int256) {
        // The returned annual rate is in 1e9 precision so we need to convert it to 1e18 precision.
        (, int256 answer, , , ) = _chainlinkAggregator.latestRoundData();
        return answer * _underlierDecimalsConversion;
    }

    /// @notice returns the description of the chainlink aggregator the proxy points to.
    function description() external view returns (string memory) {
        return _chainlinkAggregator.description();
    }
}
