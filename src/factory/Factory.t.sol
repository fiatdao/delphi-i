// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import "ds-test/test.sol";

import "src/factory/Factory.sol";

import {Oracle} from "src/oracle/Oracle.sol";
import {AggregatorOracle} from "src/aggregator/AggregatorOracle.sol";

// Value providers
import {ElementFinanceValueProvider} from "src/valueprovider/ElementFinance/ElementFinanceValueProvider.sol";

// Relayers
import {ICollybusDiscountRateRelayer} from "src/relayer/CollybusDiscountRate/ICollybusDiscountRateRelayer.sol";
import {CollybusDiscountRateRelayer} from "src/relayer/CollybusDiscountRate/CollybusDiscountRateRelayer.sol";

import {ICollybusSpotPriceRelayer} from "src/relayer/CollybusSpotPrice/ICollybusSpotPriceRelayer.sol";
import {CollybusSpotPriceRelayer} from "src/relayer/CollybusSpotPrice/CollybusSpotPriceRelayer.sol";

contract FactoryTest is DSTest {
    Factory internal factory;

    function setUp() public {
        factory = new Factory();
    }

    function buildDiscountRateDeployData()
        internal
        pure
        returns (DiscountRateDeployData memory)
    {
        NotionalData memory notional1;
        notional1.notionalData.notionalViewAddress = address(
            0x1344A36A1B56144C3Bc62E7757377D288fDE0369
        );
        notional1.notionalData.currencyID = 2;
        notional1.notionalData.maturity = 1671840000;
        notional1.notionalData.settlementDate = 1648512000;
        notional1.oracleData.timeWindow = 200;
        notional1.oracleData.maxValidTime = 600;
        notional1.oracleData.alpha = 2 * 10**17;

        NotionalData memory notional2;
        notional2.notionalData.notionalViewAddress = address(
            0x1344A36A1B56144C3Bc62E7757377D288fDE0369
        );
        notional2.notionalData.currencyID = 3;
        notional2.notionalData.maturity = 1671840000;
        notional2.notionalData.settlementDate = 1648512000;
        notional2.oracleData.timeWindow = 200;
        notional2.oracleData.maxValidTime = 600;
        notional2.oracleData.alpha = 2 * 10**17;

        ElementData memory element1;
        element1
            .vpData
            .poolId = 0x10a2f8bd81ee2898d7ed18fb8f114034a549fa59000200000000000000000090;
        element1.vpData.balancerVault = address(0x12345);
        element1.vpData.underlier = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
        element1
            .vpData
            .ePTokenBond = 0x8a2228705ec979961F0e16df311dEbcf097A2766;
        element1.vpData.timeToMaturity = 1651275535;
        element1.vpData.unitSeconds = 1000355378;
        element1.oracleData.timeWindow = 200;
        element1.oracleData.maxValidTime = 600;
        element1.oracleData.alpha = 2 * 10**17;

        ElementData memory element2;
        element2
            .vpData
            .poolId = 0x10a2f8bd81ee2898d7ed18fb8f114034a549fa59000200000000000000000090;
        element2.vpData.balancerVault = address(0x12345);
        element2.vpData.underlier = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
        element2
            .vpData
            .ePTokenBond = 0x8a2228705ec979961F0e16df311dEbcf097A2766;
        element2.vpData.timeToMaturity = 1651275535;
        element2.vpData.unitSeconds = 1000355378;
        element2.oracleData.timeWindow = 200;
        element2.oracleData.maxValidTime = 600;
        element2.oracleData.alpha = 2 * 10**17;

        ElementData memory element3;
        element3
            .vpData
            .poolId = 0x10a2f8bd81ee2898d7ed18fb8f114034a549fa59000200000000000000000090;
        element3.vpData.balancerVault = address(0x12345);
        element3.vpData.underlier = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
        element3
            .vpData
            .ePTokenBond = 0x8a2228705ec979961F0e16df311dEbcf097A2766;
        element3.vpData.timeToMaturity = 1651275535;
        element3.vpData.unitSeconds = 1000355378;
        element3.oracleData.timeWindow = 200;
        element3.oracleData.maxValidTime = 600;
        element3.oracleData.alpha = 2 * 10**17;

        AggregatorData memory elementAggregatorData;
        elementAggregatorData.tokenId = 1;

        elementAggregatorData.oracleData = new bytes[](3);
        elementAggregatorData.oracleData[0] = abi.encode(element1);
        elementAggregatorData.oracleData[1] = abi.encode(element2);
        elementAggregatorData.oracleData[2] = abi.encode(element3);

        AggregatorData memory notionalAggregatorData;
        notionalAggregatorData.tokenId = 2;
        notionalAggregatorData.oracleData = new bytes[](2);
        notionalAggregatorData.oracleData[0] = abi.encode(notional1);
        notionalAggregatorData.oracleData[1] = abi.encode(notional2);

        DiscountRateDeployData memory deployData;
        deployData.elementData = new bytes[](1);
        deployData.elementData[0] = abi.encode(elementAggregatorData);

        deployData.notionalData = new bytes[](1);
        deployData.notionalData[0] = abi.encode(notionalAggregatorData);

        return deployData;
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
        assertEq(
            address(CollybusDiscountRateRelayer(relayer).collybus()),
            collybus,
            "Collybus should be correct"
        );
    }

    function test_deployCollybusSpotPriceRelayer_createsContract() public {
        address collybus = address(0xC01115107);

        address relayer = factory.deployCollybusSpotPriceRelayer(collybus);

        // Make sure the CollybusSpotPriceRelayer_ was deployed
        assertTrue(
            relayer != address(0),
            "CollybusSpotPriceRelayer should be deployed"
        );

        // Check Collybus
        assertEq(
            address(CollybusSpotPriceRelayer(relayer).collybus()),
            collybus,
            "Collybus should be correct"
        );
    }

    function test_deployDiscountRate() public {
        DiscountRateDeployData
            memory deployData = buildDiscountRateDeployData();

        // Deploy the oracle architecture
        address discountRateRelayer = factory.deployDiscountRate(deployData);

        // Check the creation of the discount rate relayer
        assertTrue(
            discountRateRelayer != address(0),
            "CollybusDiscountPriceRelayer should be deployed"
        );
        ICollybusDiscountRateRelayer discountRelayer = ICollybusDiscountRateRelayer(
                discountRateRelayer
            );

        uint256 discountRateAggregatorCount = deployData.notionalData.length +
            deployData.elementData.length;
        assertTrue(
            discountRelayer.oracleCount() == discountRateAggregatorCount,
            "CollybusDiscountPriceRelayer discount relayer oracle count missmatch"
        );

        // Check that every aggregator was deployed
        for (uint256 index = 0; index < discountRateAggregatorCount; ++index) {
            assertTrue(
                discountRelayer.oracleAt(index) != address(0),
                "Oracle address should not be zero"
            );
        }

        uint256 notionalAggregatorCount = deployData.notionalData.length;
        for (
            uint256 aggIndex = 0;
            aggIndex < discountRateAggregatorCount;
            ++aggIndex
        ) {
            AggregatorData memory aggregatorData = abi.decode(
                deployData.notionalData[aggIndex],
                (AggregatorData)
            );
            IAggregatorOracle notionalAggregator = IAggregatorOracle(
                discountRelayer.oracleAt(aggIndex)
            );

            assertTrue(
                notionalAggregator.oracleCount() ==
                    aggregatorData.oracleData.length,
                "Notional aggregator oracle count missmatch"
            );
        }

        uint256 elementAggregatorCount = deployData.elementData.length;
        for (
            uint256 aggIndex = 0;
            aggIndex < discountRateAggregatorCount;
            ++aggIndex
        ) {
            AggregatorData memory aggregatorData = abi.decode(
                deployData.elementData[aggIndex],
                (AggregatorData)
            );
            // We need to offset the internal relayer index by the notional aggregators
            IAggregatorOracle elementAggregator = IAggregatorOracle(
                discountRelayer.oracleAt(notionalAggregatorCount + aggIndex)
            );

            assertTrue(
                elementAggregator.oracleCount() ==
                    aggregatorData.oracleData.length,
                "Notional aggregator oracle count missmatch"
            );
        }
    }
}
