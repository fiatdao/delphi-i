// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

contract Convert {
    function convert(
        int256 x,
        uint256 currentPrecision,
        uint256 targetPrecision
    ) internal pure returns (int256) {
        if (targetPrecision > currentPrecision)
            return x * int256(10**(targetPrecision - currentPrecision));

        return x / int256(10**(currentPrecision - targetPrecision));
    }

    function uconvert(
        uint256 x,
        uint256 currentPrecision,
        uint256 targetPrecision
    ) internal pure returns (uint256) {
        if (targetPrecision > currentPrecision)
            return x * 10**(targetPrecision - currentPrecision);

        return x / 10**(currentPrecision - targetPrecision);
    }
}
