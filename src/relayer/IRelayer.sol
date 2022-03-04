// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

interface IRelayer {
    enum RelayerType {
        DiscountRate,
        SpotPrice
    }

    function execute() external returns (bool);

    function executeWithRevert() external;

    function oracleCount() external view returns (uint256);

    function oracleAdd(
        address oracle_,
        bytes32 encodedToken_,
        uint256 minimumPercentageDeltaValue_
    ) external;

    function oracleRemove(address oracle_) external;

    function oracleExists(address oracle_) external view returns (bool);

    function oracleAt(uint256 index) external view returns (address);
}
