// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Oracle} from "src/oracle/Oracle.sol";
import {IVault} from "./IVault.sol";
import {Convert} from "src/oracle_implementations/discount_rate/utils/Convert.sol";

import "lib/prb-math/contracts/PRBMathSD59x18.sol";

contract ElementFiValueProvider is Oracle, Convert {
    bytes32 private immutable _poolId;
    IVault private immutable _balancerVault;
    address private immutable _poolToken;
    uint256 private immutable _poolTokenDecimals;
    address private immutable _underlier;
    uint256 private immutable _underlierDecimals;
    address private immutable _ePTokenBond;
    uint256 private immutable _ePTokenBondDecimals;
    int256 private immutable _timeScale;

    /// @notice                     Constructs the Value provider contracts with the needed Element data in order to
    ///                             calculate the annual rate.
    /// @param timeUpdateWindow_    Minimum time between updates of the value
    /// @param maxValidTime_        Maximum time for which the value is valid
    /// @param alpha_               Alpha parameter for EMA
    /// @param poolId_              poolID of the pool
    /// @param balancerVault_       Address of the balancer vault
    /// @param poolToken_           Address of the pool (LP token) contract
    /// @param poolTokenDecimals_   Precision of the pool LP token
    /// @param underlier_           Address of the underlier IERC20 token.
    /// @param underlierDecimals_   Precision of the underlier
    /// @param ePTokenBond_         Address of the bond IERC20 token.
    /// @param ePTokenBondDecimals_ Precision of the bond.
    /// @param timeScale_           Time scale used on this pool (i.e. 1/(timeStretch*secondsPerYear)) in 59x18 fixed point
    constructor(
        // Oracle parameters
        uint256 timeUpdateWindow_,
        uint256 maxValidTime_,
        int256 alpha_,
        //
        bytes32 poolId_,
        address balancerVault_,
        address poolToken_,
        uint256 poolTokenDecimals_,
        address underlier_,
        uint256 underlierDecimals_,
        address ePTokenBond_,
        uint256 ePTokenBondDecimals_,
        int256 timeScale_
    ) Oracle(timeUpdateWindow_, maxValidTime_, alpha_) {
        _poolId = poolId_;
        _balancerVault = IVault(balancerVault_);
        _poolToken = poolToken_;
        _poolTokenDecimals = poolTokenDecimals_;
        _underlier = underlier_;
        _underlierDecimals = underlierDecimals_;
        _ePTokenBond = ePTokenBond_;
        _ePTokenBondDecimals = ePTokenBondDecimals_;
        _timeScale = timeScale_;
    }

    /// @notice Calculates the implied interest rate based on reserves in the pool
    /// @dev Documentation:
    /// https://www.notion.so/fiatdao/Delphi-Interest-Rate-Oracle-System-01092c10abf14e5fb0f1353b3b24a804
    /// @dev Reverts if the block time exceeds or is equal to pool maturity.
    /// @return result The result as an signed 59.18-decimal fixed-point number.
    function getValue() external view override(Oracle) returns (int256) {
        // The base token reserves from the balancer vault in 18 digits precision
        (uint256 baseReserves, , , ) = _balancerVault.getPoolTokenInfo(
            _poolId,
            IERC20(_underlier)
        );
        baseReserves = uconvert(baseReserves, _underlierDecimals, 18);

        // The epToken balance from the balancer vault in 18 digits precision
        (uint256 ePTokenBalance, , , ) = _balancerVault.getPoolTokenInfo(
            _poolId,
            IERC20(_ePTokenBond)
        );
        ePTokenBalance = uconvert(ePTokenBalance, _ePTokenBondDecimals, 18);

        // The number of LP shares in 18 digits precision
        // These reflect the virtual reserves of the epToken in the AMM
        uint256 totalSupply = IERC20(_poolToken).totalSupply();
        totalSupply = uconvert(totalSupply, _poolTokenDecimals, 18);

        // The reserves ratio in signed 59.18 format
        int256 reservesRatio59x18 = PRBMathSD59x18.div(
            int256(ePTokenBalance + totalSupply),
            int256(baseReserves)
        );

        int256 timeRatio59x18 = PRBMathSD59x18.div(
            PRBMathSD59x18.SCALE,
            PRBMathSD59x18.fromInt(_timeScale)
        );
        // The implied per-second rate in signed 59.18 format
        int256 ratePerSecond59x18 = (PRBMathSD59x18.pow(
            reservesRatio59x18,
            timeRatio59x18
        ) - PRBMathSD59x18.SCALE);

        // The result is a 59.18 fixed-point number.
        return ratePerSecond59x18;
    }
}
