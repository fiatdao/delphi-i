// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

// Lightweight interface for Collybus
// Source: https://github.com/fiatdao/fiat-lux/blob/f49a9457fbcbdac1969c35b4714722f00caa462c/src/interfaces/ICollybus.sol
interface ICollybus {
    function updateDiscountRate(uint256 tokenId, uint256 rate) external;

    function updateSpot(address token, uint256 spot) external;
}
