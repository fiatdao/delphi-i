// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IValueProvider} from "src/valueprovider/IValueProvider.sol";
import {IVault} from "src/valueprovider/ElementFi/IVault.sol";

import {Convert} from "src/valueprovider/utils/Convert.sol";
import "lib/prb-math/contracts/PRBMathSD59x18.sol";

// @notice Emitted when trying to add pull a value for an expired pool
error ElementFiValueProvider__value_maturityLessThanBlocktime(uint256 maturity);

contract ElementFiValueProvider is IValueProvider, Convert {
    bytes32 public immutable poolId;
    address public immutable balancerVaultAddress;
    address public immutable poolToken;
    uint256 public immutable poolTokenDecimals;
    address public immutable underlier;
    uint256 public immutable underlierDecimals;
    address public immutable ePTokenBond;
    uint256 public immutable ePTokenBondDecimals;
    int256 public immutable timeScale;

    /// @notice                     Constructs the Value provider contracts with the needed Element data in order to
    ///                             calculate the annual rate.
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
        bytes32 poolId_,
        address balancerVault_,
        address poolToken_,
        uint256 poolTokenDecimals_,
        address underlier_,
        uint256 underlierDecimals_,
        address ePTokenBond_,
        uint256 ePTokenBondDecimals_,
        int256 timeScale_
    ) {
        poolId = poolId_;
        balancerVaultAddress = balancerVault_;
        poolToken = poolToken_;
        poolTokenDecimals = poolTokenDecimals_;
        underlier = underlier_;
        underlierDecimals = underlierDecimals_;
        ePTokenBond = ePTokenBond_;
        ePTokenBondDecimals = ePTokenBondDecimals_;
        timeScale = timeScale_;
    }

    /// @notice Calculates the implied interest rate based on reserves in the pool
    /// @dev Documentation:
    /// https://www.notion.so/fiatdao/Delphi-Interest-Rate-Oracle-System-01092c10abf14e5fb0f1353b3b24a804
    /// @dev Reverts if the block time exceeds or is equal to pool maturity.
    /// @return result The result as an signed 59.18-decimal fixed-point number.
function value() external view override(IValueProvider) returns (int256) {
        // The base token reserves from the balancer vault in 18 digits precision
        (uint256 baseReserves, , , ) = IVault(balancerVaultAddress).getPoolTokenInfo(
            poolId,
            IERC20(underlier)
        );
        baseReserves = uconvert(baseReserves, underlierDecimals, 18);

        // The epToken balance from the balancer vault in 18 digits precision
        (uint256 ePTokenBalance, , , ) = IVault(balancerVaultAddress).getPoolTokenInfo(
            poolId,
            IERC20(ePTokenBond)
        );
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
