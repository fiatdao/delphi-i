// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IValueProvider} from "src/valueprovider/IValueProvider.sol";
import {IVault} from "src/valueprovider/ElementFinance/IVault.sol";

import "lib/prb-math/contracts/PRBMathSD59x18.sol";

// @notice Emitted when trying to add an oracle that already exists
error ElementFinanceValueProvider__value_timeToMaturityLessThanBlockchainTime(
    uint256 timeToMaturity
);

// @notice Emitted when a token with unsupported decimals is used
error ElementFinanceValueProvider__unsupportedDecimalFormat(
    address tokenAddress
);

contract ElementFinanceValueProvider is IValueProvider {
    int256 private constant SECONDS_PER_YEAR = 31557600;

    IVault private _balancerVault;

    bytes32 private immutable _poolId;
    address private immutable _underlier;
    uint256 private immutable _underlierConversion;
    address private immutable _ePTokenBond;
    uint256 private immutable _ePTokenBondConversion;
    uint256 private immutable _timeToMaturity;
    uint256 private immutable _unitSeconds;

    /// @notice                 Constructs the Value provider contracts with the needed Element data in order to
    ///                         calculate the annual rate.
    /// @param poolId_          The poolID of the Element Convergent Curve Pool
    /// @param balancerVault_   The vault address.
    /// @param underlier_       Address of the underlier IERC20 token.
    /// @param ePTokenBond_     Address of the bond IERC20 token.
    /// @param timeToMaturity_  Timestamp for the time to maturity or the 'expiration' field from the Convergent Curve Pool contract.
    /// @param unitSeconds_     The number of seconds in the Element Convergent Curve Pool timescale.
    constructor(
        bytes32 poolId_,
        address balancerVault_,
        address underlier_,
        uint256 underlierDecimals_,
        address ePTokenBond_,
        uint256 epTolenBondDecimals_,
        uint256 timeToMaturity_,
        uint256 unitSeconds_
    ) {
        _poolId = poolId_;

        _balancerVault = IVault(balancerVault_);

        _timeToMaturity = timeToMaturity_;
        _underlier = underlier_;
        _unitSeconds = unitSeconds_;

        // For better precision we compute the needed conversion factor to scale to 18 digits fixed point number
        if (underlierDecimals_ > 18)
            revert ElementFinanceValueProvider__unsupportedDecimalFormat(
                underlier_
            );
        _underlierConversion = 18 - underlierDecimals_;

        _ePTokenBond = ePTokenBond_;

        // For better precision we compute the needed conversion factor to scale to 18 digits fixed point number
        if (epTolenBondDecimals_ > 18)
            revert ElementFinanceValueProvider__unsupportedDecimalFormat(
                ePTokenBond_
            );
        _ePTokenBondConversion = 18 - epTolenBondDecimals_;
    }

    /// @notice Calculates the annual rate used by the FIAT DAO contracts
    /// based on the token reserves, underlier reserves in a time widow, values taken
    /// from the element finance curve pool contact
    /// @dev formula documentation:
    /// https://www.notion.so/fiatdao/FIAT-Interest-Rate-Oracle-System-01092c10abf14e5fb0f1353b3b24a804
    /// @dev Reverts if the block time exceeds or is equal to the maturity date.
    /// @return result The result as an signed 59.18-decimal fixed-point number.
    function value() external view override(IValueProvider) returns (int256) {
        // Retrieve the underlier from the balancer vault.
        (uint256 underlierBalance, , , ) = _balancerVault.getPoolTokenInfo(
            _poolId,
            IERC20(_underlier)
        );

        // Convert to 18 digits precision
        underlierBalance = underlierBalance * _underlierConversion;

        // Retrieve the principal token from the balancer vault.
        (uint256 ePTokenBalance, , , ) = _balancerVault.getPoolTokenInfo(
            _poolId,
            IERC20(_ePTokenBond)
        );

        // Convert to 18 digits precision
        ePTokenBalance = ePTokenBalance * _ePTokenBondConversion;

        // Check the block time against the maturity date and revert if we're past the maturity date.
        if (block.timestamp >= _timeToMaturity) {
            revert ElementFinanceValueProvider__value_timeToMaturityLessThanBlockchainTime(
                _timeToMaturity
            );
        }

        // To better follow the formula check the documentation linked above.
        int256 timeToMaturity59x18 = PRBMathSD59x18.fromInt(
            int256(_timeToMaturity - block.timestamp)
        );

        int256 underlierTokenRatio59x18 = PRBMathSD59x18.div(
            int256(underlierBalance),
            int256(2 * ePTokenBalance + underlierBalance)
        );

        int256 timeRatio59x18 = PRBMathSD59x18.div(
            timeToMaturity59x18,
            PRBMathSD59x18.fromInt(int256(_unitSeconds))
        );

        int256 tokenUnitPrice59x18 = PRBMathSD59x18.pow(
            underlierTokenRatio59x18,
            timeRatio59x18
        );

        int256 annualRate59x18 = PRBMathSD59x18.div(
            PRBMathSD59x18.SCALE - tokenUnitPrice59x18,
            PRBMathSD59x18.div(
                timeToMaturity59x18,
                PRBMathSD59x18.fromInt(SECONDS_PER_YEAR)
            )
        );

        int256 ratePerSecond59x18 = PRBMathSD59x18.pow(
            PRBMathSD59x18.SCALE + annualRate59x18,
            PRBMathSD59x18.div(
                PRBMathSD59x18.SCALE,
                PRBMathSD59x18.fromInt(SECONDS_PER_YEAR)
            )
        ) - PRBMathSD59x18.SCALE;
        
        // The result is a 59.18 fixed-point number.
        return ratePerSecond59x18;
    }
}
