// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import {Convert} from "src/oracle_implementations/discount_rate/utils/Convert.sol";
import {IChainlinkAggregatorV3Interface} from "src/oracle_implementations/spot_price/Chainlink/ChainlinkAggregatorV3Interface.sol";
import {Oracle} from "src/oracle/Oracle.sol";

contract ChainLinkValueProvider is Oracle, Convert {
    uint256 private immutable _underlierDecimals;
    address private _underlierAddress;
    IChainlinkAggregatorV3Interface private _chainlinkAggregator;

    /// @notice                             Constructs the Value provider contracts with the needed Chainlink.
    /// @param timeUpdateWindow_            Minimum time between updates of the value
    /// @param maxValidTime_                Maximum time for which the value is valid
    /// @param alpha_                       Alpha parameter for EMA
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

        _underlierDecimals = uint256(_chainlinkAggregator.decimals());
    }

    /// @notice Retrieves the price from the chainlink aggregator
    /// @return result The result as an signed 59.18-decimal fixed-point number.
    function getValue() external view override(Oracle) returns (int256) {
        // The returned annual rate is in 1e9 precision so we need to convert it to 1e18 precision.
        (, int256 answer, , , ) = _chainlinkAggregator.latestRoundData();

        return convert(answer, _underlierDecimals, 18);
    }

    /// @notice returns the description of the chainlink aggregator the proxy points to.
    function description() external view returns (string memory) {
        return _chainlinkAggregator.description();
    }
}
