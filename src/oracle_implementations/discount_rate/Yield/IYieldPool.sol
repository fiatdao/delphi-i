// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

/// @notice The Yield pool contract interface
/// Only the useful functionality is defined in the interface.
/// For the full contract interface:
/// https://github.com/yieldprotocol/yieldspace-interfaces/blob/0266fbfd0117ff821cb2f43010a004cc44d1bfc1/IPool.sol
/// deployed contract example : https://etherscan.io/address/0x3771c99c087a81df4633b50d8b149afaa83e3c9e
interface IYieldPool {
    function ts() external view returns (int128);

    function getCache()
        external
        view
        returns (
            uint112,
            uint112,
            uint32
        );

    function getBaseBalance() external view returns (uint112);

    function getFYTokenBalance() external view returns (uint112);
}
