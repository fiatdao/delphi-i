// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Oracle} from "src/oracle/Oracle.sol";
import {IVault} from "./IVault.sol";
import {Convert} from "src/oracle_implementations/discount_rate/utils/Convert.sol";

import "lib/prb-math/contracts/PRBMathSD59x18.sol";

contract ElementFiValueProvider is Oracle, Convert {
    // @notice Emitted when trying to add pull a value for an expired pool
    error ElementFiValueProvider__value_maturityLessThanBlocktime(
        uint256 maturity
    );

    bytes32 public immutable poolId;
    address public immutable balancerVaultAddress;
    address public immutable poolToken;
    uint8 public immutable poolTokenDecimals;
    address public immutable underlier;
    uint8 public immutable underlierDecimals;
    address public immutable ePTokenBond;
    uint8 public immutable ePTokenBondDecimals;
    int256 public immutable timeScale;
    uint256 public immutable maturity;

    /// @notice                      Constructs the Value provider contracts with the needed Element data in order to
    ///                              calculate the annual rate.
    /// @param timeUpdateWindow_     Minimum time between updates of the value
    /// @param maxValidTime_         Maximum time for which the value is valid
    /// @param alpha_                Alpha parameter for EMA
    /// @param poolId_               poolID of the pool
    /// @param balancerVaultAddress_ Address of the balancer vault
    /// @param poolToken_            Address of the pool (LP token) contract
    /// @param underlier_            Address of the underlier IERC20 token
    /// @param ePTokenBond_          Address of the bond IERC20 token
    /// @param timeScale_            Time scale used on this pool (i.e. 1/(timeStretch*secondsPerYear)) in 59x18 fixed point
    /// @param maturity_             The Maturity timestamp
    constructor(
        // Oracle parameters
        uint256 timeUpdateWindow_,
        uint256 maxValidTime_,
        int256 alpha_,
        //
        bytes32 poolId_,
        address balancerVaultAddress_,
        address poolToken_,
        address underlier_,
        address ePTokenBond_,
        int256 timeScale_,
        uint256 maturity_
    ) Oracle(timeUpdateWindow_, maxValidTime_, alpha_) {
        poolId = poolId_;
        balancerVaultAddress = balancerVaultAddress_;
        poolToken = poolToken_;
        poolTokenDecimals = ERC20(poolToken_).decimals();
        underlier = underlier_;
        underlierDecimals = ERC20(underlier_).decimals();
        ePTokenBond = ePTokenBond_;
        ePTokenBondDecimals = ERC20(ePTokenBond_).decimals();
        timeScale = timeScale_;
        maturity = maturity_;
    }

    /// @notice Calculates the implied interest rate based on reserves in the pool
    /// @dev Documentation:
    /// https://www.notion.so/fiatdao/Delphi-Interest-Rate-Oracle-System-01092c10abf14e5fb0f1353b3b24a804
    /// @dev Returns if called after the maturity date
    /// @return result The result as an signed 59.18-decimal fixed-point number
    function getValue() external view override(Oracle) returns (int256) {
        // No values for matured pools
        if (block.timestamp >= maturity) {
            revert ElementFiValueProvider__value_maturityLessThanBlocktime(
                maturity
            );
        }

        // The base token reserves from the balancer vault in 18 digits precision
        (uint256 baseReserves, , , ) = IVault(balancerVaultAddress)
            .getPoolTokenInfo(poolId, IERC20(underlier));
        baseReserves = uconvert(baseReserves, underlierDecimals, 18);

        // The epToken balance from the balancer vault in 18 digits precision
        (uint256 ePTokenBalance, , , ) = IVault(balancerVaultAddress)
            .getPoolTokenInfo(poolId, IERC20(ePTokenBond));
        ePTokenBalance = uconvert(ePTokenBalance, ePTokenBondDecimals, 18);

        // The number of LP shares in 18 digits precision
        // These reflect the virtual reserves of the epToken in the AMM
        uint256 totalSupply = IERC20(poolToken).totalSupply();
        totalSupply = uconvert(totalSupply, poolTokenDecimals, 18);

        // The reserves ratio in signed 59.18 format
        int256 reservesRatio59x18 = PRBMathSD59x18.div(
            int256(ePTokenBalance + totalSupply),
            int256(baseReserves)
        );

        int256 timeRatio59x18 = PRBMathSD59x18.div(
            PRBMathSD59x18.SCALE,
            PRBMathSD59x18.fromInt(timeScale)
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
