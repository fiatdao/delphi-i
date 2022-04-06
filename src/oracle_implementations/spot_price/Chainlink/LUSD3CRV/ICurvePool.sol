// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

/// @notice Lightweight interface used to interrogate Curve pools
interface ICurvePool {
    function get_virtual_price() external view returns (uint256);

    function decimals() external view returns (uint256);
}
