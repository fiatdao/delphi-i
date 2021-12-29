// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import {IValueProvider} from "../IValueProvider.sol";
import {IYieldSpacePool} from "./IYieldSpacePool.sol";
import "lib/prb-math/contracts/PRBMathSD59x18.sol";
import "lib/abdk-libraries-solidity/ABDKMath64x64.sol";

contract YieldSpace is IValueProvider{

    IYieldSpacePool public immutable yieldPool;

    constructor(address yieldPool_) {
        yieldPool = IYieldSpacePool(yieldPool_);
    }

    /// @notice Calculates the annual rate used by the FiatDao contracts
    /// based on the token reservers, underlier reserves and time scale from the yield space contract
    /// @dev formula documentation: 
    /// https://www.notion.so/fiatdao/FIAT-Interest-Rate-Oracle-System-01092c10abf14e5fb0f1353b3b24a804
    /// @return result The result as an signed 59.18-decimal fixed-point number.
    function value() external view override(IValueProvider) returns (int256)
    {
        uint112 fyTokenReserves;
        uint112 underlierReserves;
        // The TS returned by the Yield Space contract is in 64.64 format and we need to convert it to int256
        // we do that by computing the inverse of the scale which will give us the time window in seconds
        int256 inverseTS = int256(ABDKMath64x64.toInt(ABDKMath64x64.inv(yieldPool.ts())));
        
        // Check to make sure we won't divide by 0
        if(inverseTS == 0){
            return 0;
        }

        (underlierReserves, fyTokenReserves, ) = yieldPool.getCache();

        // Basic check for data validity
        if ( fyTokenReserves == 0 || underlierReserves == 0){
            return 0;
        }

        // Using the time scale window , we compute the 1/ts and save it in 59.18 format to be used in the formula
        int256 ts59x18 = PRBMathSD59x18.div(PRBMathSD59x18.fromInt(1),
                                            PRBMathSD59x18.fromInt(inverseTS));

        // We compute the token/underlier ratio and save it in signed 59.18 format
        int256 tokenToReserveRatio59x18 = PRBMathSD59x18.div(PRBMathSD59x18.fromInt(int256(uint256(fyTokenReserves))),
                                                             PRBMathSD59x18.fromInt(int256(uint256(underlierReserves)))
                                                             );

        // Compute the result with the formula provided by the documentation
        int256 result = PRBMathSD59x18.pow(tokenToReserveRatio59x18, ts59x18) - PRBMathSD59x18.fromInt(1);

        // Result will be a 59.18 fixed-point number.
        return result;
    }
}