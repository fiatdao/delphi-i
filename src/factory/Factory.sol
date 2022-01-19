// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import {Oracle} from "src/oracle/Oracle.sol";
import {AggregatorOracle} from "src/aggregator/AggregatorOracle.sol";

// Value providers
import {ElementFinanceValueProvider} from "src/valueprovider/ElementFinance/ElementFinanceValueProvider.sol";

// Relayers
import {CollybusDiscountRateRelayer} from "src/relayer/CollybusDiscountRate/CollybusDiscountRateRelayer.sol";

contract Factory {
    function deployOracle(
        address valueProvider_,
        uint256 timeUpdateWindow_,
        uint256 maxValidTime_,
        int256 alpha_
    ) public returns (address) {
        Oracle oracle = new Oracle(
            valueProvider_,
            timeUpdateWindow_,
            maxValidTime_,
            alpha_
        );

        return address(oracle);
    }

    function deployAggregator(
        address[] memory oracles_,
        uint256 requiredValidValues_
    ) public returns (address) {
        AggregatorOracle aggregatorOracle = new AggregatorOracle();

        // Add the list of oracles
        for (uint256 i = 0; i < oracles_.length; i++) {
            aggregatorOracle.oracleAdd(oracles_[i]);
        }

        // Set the required number of valid values
        aggregatorOracle.setParam("requiredValidValues", requiredValidValues_);

        return address(aggregatorOracle);
    }

    function deployElementFinanceValueProvider(
        bytes32 poolId_,
        address balancerVault_,
        address underlier_,
        address ePTokenBond_,
        uint256 timeToMaturity_,
        uint256 unitSeconds_
    ) public returns (address) {
        ElementFinanceValueProvider elementFinanceValueProvider = new ElementFinanceValueProvider(
                poolId_,
                balancerVault_,
                underlier_,
                ePTokenBond_,
                timeToMaturity_,
                unitSeconds_
            );

        return address(elementFinanceValueProvider);
    }

    function deployCollybusDiscountRateRelayer(address collybus_) public returns (address) {
        CollybusDiscountRateRelayer collybusDiscountRateRelayer = new CollybusDiscountRateRelayer(collybus_);
        return address(collybusDiscountRateRelayer);
    }

    // function deployAggregatorForElement(
    //     // ElementFinance arguments
    //     bytes32 poolId_,
    //     address balancerVault_,
    //     address underlier_,
    //     address ePTokenBond_,
    //     uint256 timeToMaturity_,
    //     uint256 unitSeconds_
    // )
    //     public
    //     returns (
    //         // Oracle
    //         address
    //     )
    // {
    //     // Create the ElementFinanceValueProvider
    //     ElementFinanceValueProvider elementFinanceValueProvider = new ElementFinanceValueProvider(
    //             poolId_,
    //             balancerVault_,
    //             underlier_,
    //             ePTokenBond_,
    //             timeToMaturity_,
    //             unitSeconds_
    //         );

    //     // Create the oracle
    //     Oracle oracle = new Oracle(
    //         address(elementFinanceValueProvider),
    //         uint256(86400),
    //         uint256(86400),
    //         int256(0)
    //     );
    // }
}
