// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IValueProvider} from "src/valueprovider/IValueProvider.sol";
import {IVault} from "src/valueprovider/ElementFi/IVault.sol";

import {Convert} from "src/valueprovider/utils/Convert.sol";
import "lib/prb-math/contracts/PRBMathSD59x18.sol";

// @notice Emitted when trying to add pull a value for an expired pool
error ElementFiValueProvider__value_maturityLessThanBlocktime(
    uint256 maturity
);

contract ElementFiValueProvider is IValueProvider, Convert {
    bytes32 private immutable _poolId;
    IVault private immutable _balancerVault;
    address private immutable _poolToken;
    uint256 private immutable _poolTokenDecimals;
    address private immutable _underlier;
    uint256 private immutable _underlierDecimals;
    address private immutable _ePTokenBond;
    uint256 private immutable _ePTokenBondDecimals;
    uint256 private immutable _maturity;
    int256 private immutable _timeScale;

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
    /// @param maturity_            Expiration of the pool
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
        uint256 maturity_,
        int256 timeScale_
    ) {
        _poolId = poolId_;
        _balancerVault = IVault(balancerVault_);
        _poolToken = poolToken_;
        _poolTokenDecimals = poolTokenDecimals_;
        _underlier = underlier_;
        _underlierDecimals = underlierDecimals_;
        _ePTokenBond = ePTokenBond_;
        _ePTokenBondDecimals = ePTokenBondDecimals_;
        _maturity = maturity_;
        _timeScale = timeScale_;
    }

    /// @notice Calculates the implied interest rate based on reserves in the pool
    /// @dev Documentation:
    /// https://www.notion.so/fiatdao/Delphi-Interest-Rate-Oracle-System-01092c10abf14e5fb0f1353b3b24a804
    /// @dev Reverts if the block time exceeds or is equal to pool maturity.
    /// @return result The result as an signed 59.18-decimal fixed-point number.
    function value() external view override(IValueProvider) returns (int256) {
        
        // No values for matured pools
        if (block.timestamp >= _maturity) {
            revert ElementFiValueProvider__value_maturityLessThanBlocktime(
                _maturity
            );
        }

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

        // The implied per-second rate in signed 59.18 format
        int256 ratePerSecond59x18 = (PRBMathSD59x18.pow(
            reservesRatio59x18,
            _timeScale
        ) - PRBMathSD59x18.SCALE);

        // The result is a 59.18 fixed-point number.
        return ratePerSecond59x18;
    }
}
