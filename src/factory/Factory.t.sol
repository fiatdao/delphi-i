// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import "ds-test/test.sol";

import {Factory} from "src/factory/Factory.sol";

import {Oracle} from "src/oracle/Oracle.sol";
import {AggregatorOracle} from "src/aggregator/AggregatorOracle.sol";

// Value providers
import {ElementFinanceValueProvider} from "src/valueprovider/ElementFinance/ElementFinanceValueProvider.sol";

// Relayers
import {CollybusDiscountRateRelayer} from "src/relayer/CollybusDiscountRate/CollybusDiscountRateRelayer.sol";

contract FactoryTest is DSTest {
    Factory internal factory;

    function setUp() public {
        factory = new Factory();
    }

    function test_deploy_ElementFinanceValueProvider_createsContract() public {
        bytes32 poolId = 0x10a2f8bd81ee2898d7ed18fb8f114034a549fa59000200000000000000000090;
        // Balancer vault
        address balancerVault = 0xBA12222222228d8Ba445958a75a0704d566BF2C8;
        // Underlier (USDC)
        address underlier = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
        // Principal bond (Element Principal Token yvUSDC-28JAN22)
        address ePTokenBond = 0x8a2228705ec979961F0e16df311dEbcf097A2766;
        // Timestamp to maturity,
        uint256 timeToMaturity = 1651275535;
        // Time scale in seconds
        uint256 unitSeconds = 1000355378;

        // Deploy the Element Finance Value Provider
        ElementFinanceValueProvider elementFinanceValueProvider = ElementFinanceValueProvider(
                factory.deployElementFinanceValueProvider(
                    poolId,
                    balancerVault,
                    underlier,
                    ePTokenBond,
                    timeToMaturity,
                    unitSeconds
                )
            );

        assertTrue(
            address(elementFinanceValueProvider) != address(0),
            "Element Finance Value Provider should be deployed"
        );

        // Check the pool ID
        assertEq(
            poolId,
            elementFinanceValueProvider.poolId(),
            "Pool ID should be correct"
        );
        // Check the balancer vault
        assertEq(
            balancerVault,
            address(elementFinanceValueProvider.balancerVault()),
            "Balancer vault should be correct"
        );
        // Check the underlier
        assertEq(
            underlier,
            elementFinanceValueProvider.underlier(),
            "Underlier should be correct"
        );
        // Check the principal bond
        assertEq(
            ePTokenBond,
            elementFinanceValueProvider.ePTokenBond(),
            "Principal bond should be correct"
        );
        // Check the time to maturity
        assertEq(
            timeToMaturity,
            elementFinanceValueProvider.timeToMaturity(),
            "Time to maturity should be correct"
        );
        // Check the time scale
        assertEq(
            unitSeconds,
            elementFinanceValueProvider.unitSeconds(),
            "Time scale should be correct"
        );
    }    

    function test_deployOracle_createsContract(
        address valueProvider_,
        uint256 timeUpdateWindow_,
        uint256 maxValidTime_,
        int256 alpha_
    ) public {
        Oracle oracle = Oracle(
            factory.deployOracle(
                valueProvider_,
                timeUpdateWindow_,
                maxValidTime_,
                alpha_
            )
        );

        // Make sure the Oracle was deployed
        assertTrue(address(oracle) != address(0), "Oracle should be deployed");

        // Check the Oracle's parameters
        assertEq(
            valueProvider_,
            address(Oracle(oracle).valueProvider()),
            "Value provider should be correct"
        );
        assertEq(
            timeUpdateWindow_,
            Oracle(oracle).timeUpdateWindow(),
            "Time update window should be correct"
        );
        assertEq(
            maxValidTime_,
            Oracle(oracle).maxValidTime(),
            "Max valid time should be correct"
        );
        assertEq(alpha_, Oracle(oracle).alpha(), "Alpha should be correct");
    }

    function test_deployAggregator_createsContract() public {
        address[] memory oracles = new address[](3);
        oracles[0] = address(1);
        oracles[1] = address(2);
        oracles[2] = address(3);

        uint256 requiredValidValues = 3;

        AggregatorOracle aggregator = AggregatorOracle(
            factory.deployAggregator(oracles, requiredValidValues)
        );

        // Make sure the Aggregator was deployed
        assertTrue(
            address(aggregator) != address(0),
            "Aggregator should be deployed"
        );

        // Check if the oracles are added
        assertEq(
            aggregator.oracleCount(),
            oracles.length,
            "Oracle count should be correct"
        );
        for (uint256 i = 0; i < oracles.length; i++) {
            assertTrue(
                aggregator.oracleExists(oracles[i]),
                "Oracle should exist"
            );
        }

        // Check the required valid values
        assertEq(
            aggregator.requiredValidValues(),
            requiredValidValues,
            "Required valid values should be correct"
        );
    }

    function test_deployCollybusDiscountRateRelayer_createsContract() public {
        address collybus = address(0xC0111b005);

        address relayer = factory.deployCollybusDiscountRateRelayer(collybus);

        // Make sure the CollybusDiscountRateRelayer was deployed
        assertTrue(
            relayer != address(0),
            "CollybusDiscountRateRelayer should be deployed"
        );

        // Check Collybus
        assertEq(address(CollybusDiscountRateRelayer(relayer).collybus()), collybus, "Collybus should be correct");
    }


    // function test_deployAggregatorForElement() public {
    //     bytes32 poolId_ = 0x10a2f8bd81ee2898d7ed18fb8f114034a549fa59000200000000000000000090;
    //     // Balancer vault
    //     address balancerVault_ = 0xBA12222222228d8Ba445958a75a0704d566BF2C8;
    //     // Underlier (USDC)
    //     address underlier_ = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    //     // Principal bond (Element Principal Token yvUSDC-28JAN22)
    //     address ePTokenBond_ = 0x8a2228705ec979961F0e16df311dEbcf097A2766;
    //     // Timestamp to maturity,
    //     uint256 timeToMaturity_ = 1651275535;
    //     // Time scale in seconds
    //     uint256 unitSeconds_ = 1000355378;

    //     factory.deployAggregatorForElement(
    //         poolId_,
    //         balancerVault_,
    //         underlier_,
    //         ePTokenBond_,
    //         timeToMaturity_,
    //         unitSeconds_
    //     );
    // }
}
