// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import {IYieldPool} from "./IYieldPool.sol";
import "lib/prb-math/contracts/PRBMathSD59x18.sol";
import "lib/abdk-libraries-solidity/ABDKMath64x64.sol";
import {Oracle} from "src/oracle/Oracle.sol";




contract YieldValueProvider is Oracle {
    // @notice Emitted when trying to add pull a value for an expired pool
    error YieldProtocolValueProvider__value_maturityLessThanBlocktime(
        uint256 maturity
    );

    IYieldPool public immutable _pool;
    uint256 private immutable _maturity;
    int256 private immutable _timeScale;

    /// @notice                     Constructs the Value provider contracts with the needed Element data in order to
    ///                             calculate the annual rate.
    /// @param timeUpdateWindow_    Minimum time between updates of the value
    /// @param maxValidTime_        Maximum time for which the value is valid
    /// @param alpha_               Alpha parameter for EMA    
    /// @param pool_                Address of the pool
    /// @param maturity_            Expiration of the pool
    /// @param timeScale_           Time scale used on this pool (i.e. 1/(timeStretch*secondsPerYear)) in 59x18 fixed point
    constructor(
        // Oracle parameters
        uint256 timeUpdateWindow_,
        uint256 maxValidTime_,
        int256 alpha_,
        //
        address pool_,
        uint256 maturity_,
        int256 timeScale_
    ) Oracle(timeUpdateWindow_, maxValidTime_, alpha_) {
        _pool = IYieldPool(pool_);
        _maturity = maturity_;
        _timeScale = timeScale_;
    }

    /// @notice Calculates the implied interest rate based on reserves in the pool
    /// @dev Documentation:
    /// https://www.notion.so/fiatdao/Delphi-Interest-Rate-Oracle-System-01092c10abf14e5fb0f1353b3b24a804
    /// @dev Reverts if the block time exceeds or is equal to pool maturity.
    /// @return result The result as an signed 59.18-decimal fixed-point number.
    function getValue() external view override(Oracle) returns (int256) {
        // No values for matured pools
        if (block.timestamp >= _maturity) {
            revert YieldProtocolValueProvider__value_maturityLessThanBlocktime(
                _maturity
            );
        }

        // The base token and fyToken reserves from YieldSpace
        // fyTokenReserves already contains the virtual reserves so no need to add LP totalSupply
        uint112 fyTokenReserves;
        uint112 baseReserves;
        (baseReserves, fyTokenReserves, ) = _pool.getCache();

        // The reserves ratio in signed 59.18 format
        int256 reservesRatio59x18 = PRBMathSD59x18.div(
            PRBMathSD59x18.fromInt(int256(uint256(fyTokenReserves))),
            PRBMathSD59x18.fromInt(int256(uint256(baseReserves)))
        );

        // The implied per-second rate in signed 59.18 format
        int256 ratePerSecond59x18 = (PRBMathSD59x18.pow(
            reservesRatio59x18,
            _timeScale
        ) - PRBMathSD59x18.SCALE);

        // The result is a 59.18 fixed-point number.
        return ratePerSecond59x18;
    }
}
