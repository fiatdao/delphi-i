pragma solidity ^0.8.0;

interface ICollybus {
    function updateDiscountRate(uint256 tokenId, int256 rate) external;
}
