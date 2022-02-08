// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import {Convert} from "src/oracle_implementations/discount_rate/utils/Convert.sol";

import {IYieldPool} from "./IYieldPool.sol";
import "lib/prb-math/contracts/PRBMathSD59x18.sol";
import {Oracle} from "src/oracle/Oracle.sol";

contract YieldValueProvider is Oracle, Convert {
    // @notice Emitted when trying to add pull a value for an expired pool
    error YieldProtocolValueProvider__getValue_maturityLessThanBlocktime(
        uint256 maturity
    );

    uint256 cumulativeBalanceRatioLast;
    uint32 blockTimestampLast;

    address public immutable poolAddress;
    uint256 public immutable maturity;
    int256 public immutable timeScale;

    /// @notice                     Constructs the Value provider contracts with the needed Element data in order to
    ///                             calculate the annual rate.
    /// @param timeUpdateWindow_    Minimum time between updates of the value
    /// @param maxValidTime_        Maximum time for which the value is valid
    /// @param alpha_               Alpha parameter for EMA
    /// @param poolAddress_                Address of the pool
    /// @param maturity_            Expiration of the pool
    /// @param timeScale_           Time scale used on this pool (i.e. 1/(timeStretch*secondsPerYear)) in 59x18 fixed point
    constructor(
        // Oracle parameters
        uint256 timeUpdateWindow_,
        uint256 maxValidTime_,
        int256 alpha_,
        //
        address poolAddress_,
        uint256 maturity_,
        int256 timeScale_
    ) Oracle(timeUpdateWindow_, maxValidTime_, alpha_) {
        poolAddress = poolAddress_;
        maturity = maturity_;
        timeScale = timeScale_;

        // Load the initial values from the pool
        (, , blockTimestampLast) = IYieldPool(poolAddress_).getCache();
        cumulativeBalanceRatioLast = uconvert(
            IYieldPool(poolAddress_).cumulativeBalancesRatio(),
            27,
            18
        );
    }

    /// @notice Calculates the implied interest rate based on reserves in the pool
    /// @dev Documentation:
    /// https://www.notion.so/fiatdao/Delphi-Interest-Rate-Oracle-System-01092c10abf14e5fb0f1353b3b24a804
    /// @dev Reverts if the block time exceeds or is equal to pool maturity.
    /// @return result The result as an signed 59.18-decimal fixed-point number.
    function getValue() external override(Oracle) returns (int256) {
        // No values for matured pools
        if (block.timestamp >= maturity) {
            revert YieldProtocolValueProvider__getValue_maturityLessThanBlocktime(
                maturity
            );
        }

        // Get the current block timestamp for the Cumulative Balance Ratio
        (, , uint32 blockTimestamp) = IYieldPool(poolAddress).getCache();

        // Compute the elapsed time
        uint32 timeElapsed = blockTimestamp - blockTimestampLast;

        // Get the current cumulative balance ratio and scale it to 18 digit precision
        uint256 cumulativeBalanceRatio = uconvert(
            IYieldPool(poolAddress).cumulativeBalancesRatio(),
            27,
            18
        );

        // Compute the scaled cumulative balance ratio
        // Reverting here if timeElapsed is 0 is accepted
        int256 scaledCumulativeBalance59x18 = PRBMathSD59x18.div(
            int256(cumulativeBalanceRatio - cumulativeBalanceRatioLast),
            PRBMathSD59x18.fromInt(int256(uint256(timeElapsed)))
        );

        // Save the last used values
        blockTimestampLast = blockTimestamp;
        cumulativeBalanceRatioLast = cumulativeBalanceRatio;

        // Compute the per-second rate in signed 59.18 format
        int256 ratePerSecond59x18 = (PRBMathSD59x18.pow(
            scaledCumulativeBalance59x18,
            timeScale
        ) - PRBMathSD59x18.SCALE);

        // The result is a 59.18 fixed-point number.
        return ratePerSecond59x18;
    }
}
