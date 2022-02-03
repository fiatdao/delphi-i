// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

interface IAggregatorOracle {
    function oracleExists(address oracle) external view returns (bool);

    function oracleAdd(address oracle) external;

    function oracleRemove(address oracle) external;

    function oracleCount() external view returns (uint256);

    function oracleAt(uint256 index) external view returns (address);
    
    function setParam(bytes32 param, uint256 value) external;
}
