// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import "ds-test/test.sol";

import "src/factory/Factory.sol";

import {Guarded} from "src/guarded/Guarded.sol";
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
        returns (DiscountRateDeployData memory)
    {
        NotionalVPData memory notionalValueProvider = NotionalVPData({
            notionalViewAddress: 0x1344A36A1B56144C3Bc62E7757377D288fDE0369,
            currencyID: 2,
            maturity: 1671840000,
            settlementDate: 1648512000
        });

        OracleData memory notionalOracleData = OracleData({
            valueProviderData: abi.encode(notionalValueProvider),
            timeWindow: 200,
            maxValidTime: 600,
            alpha: 2 * 10**17,
            providerType: uint8(Factory.ValueProviderType.Notional)
        });

        AggregatorData memory notionalAggregator = AggregatorData({
            tokenId: 1,
            oracleData: new bytes[](1),
            requiredValidValues: 1,
            minimumThresholdValue: 10**14
        });

        notionalAggregator.oracleData[0] = abi.encode(notionalOracleData);

        ElementVPData memory elementValueProvider = ElementVPData({
            poolId: 0x10a2f8bd81ee2898d7ed18fb8f114034a549fa59000200000000000000000090,
            balancerVault: address(0x12345),
            underlier: 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48,
            ePTokenBond: 0x8a2228705ec979961F0e16df311dEbcf097A2766,
            timeToMaturity: 1651275535,
            unitSeconds: 1000355378
        });

        OracleData memory elementOracleData = OracleData({
            valueProviderData: abi.encode(elementValueProvider),
            timeWindow: 200,
            maxValidTime: 600,
            alpha: 2 * 10**17,
            providerType: uint8(Factory.ValueProviderType.Element)
        });

        AggregatorData memory elementAggregator = AggregatorData({
            tokenId: 2,
            oracleData: new bytes[](1),
            requiredValidValues: 1,
            minimumThresholdValue: 10**14
        });

        elementAggregator.oracleData[0] = abi.encode(elementOracleData);

        DiscountRateDeployData memory deployData;
        deployData.aggregatorData = new bytes[](2);
        deployData.aggregatorData[0] = abi.encode(elementAggregator);
        deployData.aggregatorData[1] = abi.encode(notionalAggregator);

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

    function test_deploy_Oracle_createsContract(
        uint256 timeUpdateWindow_,
        uint256 maxValidTime_,
        int256 alpha_
    ) public {
        ElementVPData memory elementValueProvider = ElementVPData({
            poolId: 0x10a2f8bd81ee2898d7ed18fb8f114034a549fa59000200000000000000000090,
            balancerVault: address(0x12345),
            underlier: 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48,
            ePTokenBond: 0x8a2228705ec979961F0e16df311dEbcf097A2766,
            timeToMaturity: 1651275535,
            unitSeconds: 1000355378
        });

        OracleData memory elementDataOracle = OracleData({
            valueProviderData: abi.encode(elementValueProvider),
            timeWindow: timeUpdateWindow_,
            maxValidTime: maxValidTime_,
            alpha: alpha_,
            providerType: uint8(Factory.ValueProviderType.Element)
        });

        AggregatorOracle aggregatorOracle = new AggregatorOracle();
        aggregatorOracle.allowCaller(
            AggregatorOracle.oracleAdd.selector,
            address(factory)
        );

        Oracle oracle = Oracle(
            factory.deployOracle(
                abi.encode(elementDataOracle),
                address(aggregatorOracle)
            )
        );

        // Make sure the Oracle was deployed
        assertTrue(address(oracle) != address(0), "Oracle should be deployed");

        // Check the Oracle's parameters
        assertTrue(
            address(Oracle(oracle).valueProvider()) != address(0),
            "Value provider should be correct"
        );
        assertEq(
            elementDataOracle.timeWindow,
            Oracle(oracle).timeUpdateWindow(),
            "Time update window should be correct"
        );
        assertEq(
            elementDataOracle.maxValidTime,
            Oracle(oracle).maxValidTime(),
            "Max valid time should be correct"
        );
        assertEq(
            elementDataOracle.alpha,
            Oracle(oracle).alpha(),
            "Alpha should be correct"
        );
    }

    function test_deploy_Aggregator_createsContract() public {
        ElementVPData memory elementValueProvider = ElementVPData({
            poolId: 0x10a2f8bd81ee2898d7ed18fb8f114034a549fa59000200000000000000000090,
            balancerVault: address(0x12345),
            underlier: 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48,
            ePTokenBond: 0x8a2228705ec979961F0e16df311dEbcf097A2766,
            timeToMaturity: 1651275535,
            unitSeconds: 1000355378
        });

        OracleData memory elementDataOracle = OracleData({
            valueProviderData: abi.encode(elementValueProvider),
            timeWindow: 200,
            maxValidTime: 600,
            alpha: 2 * 10**17,
            providerType: uint8(Factory.ValueProviderType.Element)
        });

        AggregatorData memory elementAggregatorData;
        elementAggregatorData.tokenId = 1;
        elementAggregatorData.requiredValidValues = 1;
        elementAggregatorData.oracleData = new bytes[](1);
        elementAggregatorData.oracleData[0] = abi.encode(elementDataOracle);

        address relayerAddress = factory.deployCollybusDiscountRateRelayer(
            address(0x1234)
        );

        // Make sure the Relayer was deployed
        assertTrue(relayerAddress != address(0), "Relayer should be deployed");

        address aggregatorAddress = factory.deployAggregator(
            abi.encode(elementAggregatorData),
            relayerAddress
        );

        // Make sure the Aggregator was deployed
        assertTrue(
            aggregatorAddress != address(0),
            "Aggregator should be deployed"
        );

        AggregatorOracle aggregator = AggregatorOracle(aggregatorAddress);
        // Check if the oracles are added
        assertEq(
            aggregator.oracleCount(),
            elementAggregatorData.oracleData.length,
            "Oracle count should be correct"
        );

        // Iterate and check each oracle was deployed
        for (uint256 i = 0; i < elementAggregatorData.oracleData.length; i++) {
            assertTrue(
                aggregator.oracleAt(i) != address(0),
                "Oracle should exist"
            );
        }

        // Check the required valid values
        assertEq(
            aggregator.requiredValidValues(),
            elementAggregatorData.requiredValidValues,
            "Required valid values should be correct"
        );
    }

    function test_deploy_CollybusDiscountRateRelayer_createsContract() public {
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

    function test_deploy_CollybusSpotPriceRelayer_createsContract() public {
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

    function test_deploy_FullDiscountRateArchitecture() public {
        DiscountRateDeployData
            memory deployData = buildDiscountRateDeployData();

        // Deploy the oracle architecture
        address discountRateRelayer = factory.deployDiscountRateArchitecture(
            deployData,
            address(0x1234)
        );

        // Check the creation of the discount rate relayer
        assertTrue(
            discountRateRelayer != address(0),
            "CollybusDiscountPriceRelayer should be deployed"
        );

        assertEq(
            ICollybusDiscountRateRelayer(discountRateRelayer).oracleCount(),
            deployData.aggregatorData.length,
            "Discount rate relayer invalid aggregator count"
        );
    }

    function test_deploy_AddAggregator() public {
        DiscountRateDeployData
            memory deployData = buildDiscountRateDeployData();

        // Deploy the oracle architecture
        address discountRateRelayer = factory.deployDiscountRateArchitecture(
            deployData,
            address(0x1234)
        );

        uint256 aggregatorCount = ICollybusDiscountRateRelayer(
            discountRateRelayer
        ).oracleCount();

        NotionalVPData memory notionalValueProvider = NotionalVPData({
            notionalViewAddress: 0x1344A36A1B56144C3Bc62E7757377D288fDE0369,
            currencyID: 2,
            maturity: 1671840000,
            settlementDate: 1648512000
        });

        OracleData memory notionalOracleData = OracleData({
            valueProviderData: abi.encode(notionalValueProvider),
            timeWindow: 200,
            maxValidTime: 600,
            alpha: 2 * 10**17,
            providerType: uint8(Factory.ValueProviderType.Notional)
        });

        AggregatorData memory notionalAggregator = AggregatorData({
            tokenId: 3,
            oracleData: new bytes[](1),
            requiredValidValues: 1,
            minimumThresholdValue: 10**14
        });

        notionalAggregator.oracleData[0] = abi.encode(notionalOracleData);

        address aggregatorAddress = factory.deployAggregator(
            abi.encode(notionalAggregator),
            discountRateRelayer
        );

        assertEq(
            aggregatorCount + 1,
            ICollybusDiscountRateRelayer(discountRateRelayer).oracleCount(),
            "Replayer should contain the new aggregator"
        );

        assertTrue(
            ICollybusDiscountRateRelayer(discountRateRelayer).oracleExists(
                aggregatorAddress
            ),
            "Aggregator should exist"
        );
    }

    function test_deploy_AddOracle() public {
        DiscountRateDeployData
            memory deployData = buildDiscountRateDeployData();

        // Deploy the oracle architecture
        address discountRateRelayer = factory.deployDiscountRateArchitecture(
            deployData,
            address(0x1234)
        );

        address firstAggregatorAddress = ICollybusDiscountRateRelayer(
            discountRateRelayer
        ).oracleAt(0);

        NotionalVPData memory notionalValueProvider = NotionalVPData({
            notionalViewAddress: 0x1344A36A1B56144C3Bc62E7757377D288fDE0369,
            currencyID: 2,
            maturity: 1671840000,
            settlementDate: 1648512000
        });

        OracleData memory notionalOracleData = OracleData({
            valueProviderData: abi.encode(notionalValueProvider),
            timeWindow: 200,
            maxValidTime: 600,
            alpha: 2 * 10**17,
            providerType: uint8(Factory.ValueProviderType.Notional)
        });

        uint256 oracleCount = IAggregatorOracle(firstAggregatorAddress)
            .oracleCount();
        factory.deployOracle(
            abi.encode(notionalOracleData),
            firstAggregatorAddress
        );

        assertEq(
            oracleCount + 1,
            IAggregatorOracle(firstAggregatorAddress).oracleCount(),
            "Aggregator should contain the new oracle"
        );

        // check exists
    }
}
