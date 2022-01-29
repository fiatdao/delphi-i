// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import {IValueProvider} from "../IValueProvider.sol";
import {IYieldPool} from "./IYieldPool.sol";
import "lib/prb-math/contracts/PRBMathSD59x18.sol";
import "lib/abdk-libraries-solidity/ABDKMath64x64.sol";

contract YieldValueProvider is IValueProvider {
    IYieldPool public immutable yieldPool;

    constructor(address yieldPool_) {
        yieldPool = IYieldPool(yieldPool_);
    }

    /// @notice Calculates the per second rate used by the FiatDao contracts
    /// based on the token reservers, underlier reserves and time scale from the yield contract
    /// @dev formula documentation:
    /// https://www.notion.so/fiatdao/Delphi-Interest-Rate-Oracle-System-01092c10abf14e5fb0f1353b3b24a804
    /// @return result The result as an signed 59.18-decimal fixed-point number.
    function value() external view override(IValueProvider) returns (int256) {

        // The timeScale parameter from YieldSpace
        // This number is in 64.64 format but we need 59.18 for exponentiation. Thus we first compute
        // the inverse (this is unitSeconds), convert this int to 59.18 and compute inverse again
        int256 unitSeconds = int256(
            ABDKMath64x64.toInt(ABDKMath64x64.inv(yieldPool.ts()))
        );
        int256 ts59x18 = PRBMathSD59x18.div(
            PRBMathSD59x18.SCALE,
            PRBMathSD59x18.fromInt(unitSeconds)
        );

        // The base token and fyToken reserves from YieldSpace
        // fyTokenReserves already contains the virtual reserves so no need to add LP totalSupply
        uint112 fyTokenReserves;
        uint112 baseReserves;
        (baseReserves, fyTokenReserves, ) = yieldPool.getCache();

        // The reserves ratio in signed 59.18 format
        int256 reservesRatio59x18 = PRBMathSD59x18.div(
            PRBMathSD59x18.fromInt(int256(uint256(fyTokenReserves))),
            PRBMathSD59x18.fromInt(int256(uint256(baseReserves)))
        );

        // The implied per-second rate in signed 59.18 format
        int256 ratePerSecond = (PRBMathSD59x18.pow(
            reservesRatio59x18,
            ts59x18
        ) - PRBMathSD59x18.SCALE);

        // The result is a 59.18 fixed-point number.
        return ratePerSecond;
    }
}
