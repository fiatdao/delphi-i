// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;
import {IRelayer} from "src/relayer/IRelayer.sol";

interface ICollybusDiscountRateRelayer is IRelayer {
    function oracleCount() external view returns (uint256);

    function oracleExists(address oracle_) external view returns (bool);

    function oracleAt(uint256 index) external view returns (address);

    function oracleAdd(
        address oracle_,
        uint256 tokenId_,
        uint256 minimumThresholdValue_
    ) external;

    function oracleRemove(address oracle_) external;
}
