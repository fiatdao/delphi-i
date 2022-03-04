// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import {Convert} from "src/oracle_implementations/discount_rate/utils/Convert.sol";
import {IChainlinkAggregatorV3Interface} from "src/oracle_implementations/spot_price/Chainlink/ChainlinkAggregatorV3Interface.sol";
import {Oracle} from "src/oracle/Oracle.sol";

contract ChainLinkValueProvider is Oracle, Convert {
    uint8 public immutable underlierDecimals;
    address public underlierAddress;
    address public chainlinkAggregatorAddress;

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
        chainlinkAggregatorAddress = chainlinkAggregatorAddress_;
        underlierDecimals = IChainlinkAggregatorV3Interface(
            chainlinkAggregatorAddress_
        ).decimals();
    }

    /// @notice Retrieves the price from the chainlink aggregator
    /// @return result The result as an signed 59.18-decimal fixed-point number.
    function getValue() external view override(Oracle) returns (int256) {
        // We want to allow only self-execution for the getValue function
        // By doing this make sure that the update flow can be triggered only by whitelisted actors
        if (msg.sender != address(this)) {
            revert Oracle__getValue_notAuthorized();
        }

        // The returned annual rate is in 1e9 precision so we need to convert it to 1e18 precision.
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
