// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

interface IAggregatorOracle {
    function oracleExists(address oracle_) external view returns (bool);

    function oracleAdd(address oracle_) external;

    function oracleRemove(address oracle_) external;

    function oracleCount() external view returns (uint256);

    function oracleAt(uint256 index_) external view returns (address);

    function setParam(bytes32 param_, uint256 value_) external;
}
