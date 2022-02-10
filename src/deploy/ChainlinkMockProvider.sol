// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;
import {IChainlinkAggregatorV3Interface} from "src/oracle_implementations/spot_price/Chainlink/ChainlinkAggregatorV3Interface.sol";

contract ChainlinkMockProvider is IChainlinkAggregatorV3Interface{
    
    int256 answer;

    function setAnswer(int256 answer_) external {
        answer = answer_;
    }

    function decimals() external view override(IChainlinkAggregatorV3Interface) returns (uint8)
    {
        return 18;
    }

    function description() external view override(IChainlinkAggregatorV3Interface) returns (string memory)
    {
        return "MOCK / USD ";
    }

    function version() external view override(IChainlinkAggregatorV3Interface) returns (uint256)
    {
        return 0;
    }

    function getRoundData(uint80 _roundId)
        external
        view
        override(IChainlinkAggregatorV3Interface)
        returns (
            uint80 roundId_,
            int256 answer_,
            uint256 startedAt_,
            uint256 updatedAt_,
            uint80 answeredInRound_
        ){
            roundId_ = 92233720368547764552;
            answer_ = answer;
            startedAt_ = 1644474147;
            updatedAt_ = 1644474147;
            answeredInRound_ = 92233720368547764552;
    }

    function latestRoundData()
        external
        view
        override(IChainlinkAggregatorV3Interface)
        returns (
            uint80 roundId_,
            int256 answer_,
            uint256 startedAt_,
            uint256 updatedAt_,
            uint80 answeredInRound_
        )
        {
            roundId_ = 92233720368547764552;
            answer_ = answer;
            startedAt_ = 1644474147;
            updatedAt_ = 1644474147;
            answeredInRound_ = 92233720368547764552;
        }

}