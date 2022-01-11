// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IValueProvider} from "../IValueProvider.sol";
import {IVault} from "./IVault.sol";

import "lib/prb-math/contracts/PRBMathSD59x18.sol";

contract ElementFinanceValueProvider is IValueProvider {
    IVault private _balancerVault;

    bytes32 private immutable _poolId;
    address private immutable _underlier;
    address private immutable _ePTokenBond;
    int256 private immutable _ts;

    /// @notice                 Constructs the Value provider contracts with the needed Element data in order to
    ///                         calculate the annual rate.
    /// @param poolId_          The poolID of the Element Convergent Curve Pool
    /// @param balancerVault_   The vault address.
    /// @param underlier_       Address of the underlier IERC20 token.
    /// @param ePTokenBond_     Address of the bond IERC20 token.
    /// @param unitSeconds_     The number of seconds in the Element Convergent Curve Pool timescale.
    constructor(
        bytes32 poolId_,
        address balancerVault_,
        address underlier_,
        address ePTokenBond_,
        uint256 unitSeconds_
    ) {
        _poolId = poolId_;

        _balancerVault = IVault(balancerVault_);

        _underlier = underlier_;
        _ePTokenBond = ePTokenBond_;

        // Using the time scale window , we compute the 1/timescale and save it in 59.18 format to be used in the formula
        // We can compute the TS from the start because it is immutable in the convergent curve contract
        // and we can be sure it will not change.
        _ts = PRBMathSD59x18.div(
            PRBMathSD59x18.fromInt(1),
            PRBMathSD59x18.fromInt(int256(unitSeconds_))
        );
    }

    /// @notice Calculates the annual rate used by the FIAT DAO contracts
    /// based on the token reserves, underlier reserves and time scale from the element finance curve pool contact
    /// @dev formula documentation:
    /// https://www.notion.so/fiatdao/FIAT-Interest-Rate-Oracle-System-01092c10abf14e5fb0f1353b3b24a804
    /// @return result The result as an signed 59.18-decimal fixed-point number.
    function value() external view override(IValueProvider) returns (int256) {
        // Retrieve the underlier and pricipal token reserves from the balancer vault.
        (uint256 underlierBalance, , , ) = _balancerVault.getPoolTokenInfo(
            _poolId,
            IERC20(_underlier)
        );

        (uint256 ePTokenBalance, , , ) = _balancerVault.getPoolTokenInfo(
            _poolId,
            IERC20(_ePTokenBond)
        );

        // We compute the token/underlier ratio and save it in signed 59.18 format
        int256 tokenToReserveRatio59x18 = PRBMathSD59x18.div(
            PRBMathSD59x18.fromInt(int256(uint256(ePTokenBalance))),
            PRBMathSD59x18.fromInt(int256(uint256(underlierBalance)))
        );

        // Compute the result with the formula provided by the documentation
        // Rate is per second so we scale it per Julien year, 365.25 days.
        int256 result = (PRBMathSD59x18.pow(tokenToReserveRatio59x18, _ts) -
            PRBMathSD59x18.fromInt(1)) * 31557600;

        // The result is a 59.18 fixed-point number.
        return result;
    }
}
