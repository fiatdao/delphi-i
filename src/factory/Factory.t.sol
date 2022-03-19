// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import "ds-test/test.sol";
import {Hevm} from "../test/utils/Hevm.sol";
import {Caller} from "src/test/utils/Caller.sol";
import {MockProvider} from "@cleanunicorn/mockprovider/src/MockProvider.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import "./Factory.sol";
import {Guarded} from "../guarded/Guarded.sol";
import {Oracle} from "../oracle/Oracle.sol";

import {AggregatorOracle} from "../aggregator/AggregatorOracle.sol";
// Contract Deployers and dependencies
import {ElementFiValueProviderFactory} from "./ElementFiValueProviderFactory.sol";
import {NotionalFinanceValueProviderFactory} from "./NotionalFinanceValueProviderFactory.sol";
import {YieldValueProviderFactory} from "./YieldValueProviderFactory.sol";
import {ChainlinkValueProviderFactory} from "./ChainlinkValueProviderFactory.sol";
import {AggregatorOracleFactory} from "./AggregatorOracleFactory.sol";
import {RelayerFactory} from "./RelayerFactory.sol";
import {ChainlinkMockProvider} from "../deploy/ChainlinkMockProvider.sol";
import {IYieldPool} from "../oracle_implementations/discount_rate/Yield/IYieldPool.sol";
import {IChainlinkAggregatorV3Interface} from "../oracle_implementations/spot_price/Chainlink/ChainlinkAggregatorV3Interface.sol";

// Relayers
import {IRelayer} from "../relayer/IRelayer.sol";
import {Relayer} from "../relayer/Relayer.sol";

/*
contract FactoryTest is DSTest {
    error FactoryTest__invalidDiscountRateAggregatorType(uint256 valueType);
    error FactoryTest__invalidSpotPriceAggregatorType(uint256 valueType);

    Factory internal factory;

    ElementFiValueProviderFactory internal elementFiValueProviderFactoryMock;
    NotionalFinanceValueProviderFactory
        internal notionalValueProviderFactoryMock;
    YieldValueProviderFactory internal yieldValueProviderFactoryMock;
    ChainlinkValueProviderFactory internal chainlinkValueProviderFactoryMock;
    AggregatorOracleFactory internal aggregatorOracleFactoryMock;
    RelayerFactory internal relayerFactoryMock;

    function setUp() public {
        // Create all the contract factories needed by the main factory
        elementFiValueProviderFactoryMock = new ElementFiValueProviderFactory();
        notionalValueProviderFactoryMock = new NotionalFinanceValueProviderFactory();
        yieldValueProviderFactoryMock = new YieldValueProviderFactory();
        chainlinkValueProviderFactoryMock = new ChainlinkValueProviderFactory();
        aggregatorOracleFactoryMock = new AggregatorOracleFactory();
        relayerFactoryMock = new RelayerFactory();

        factory = new Factory(
            address(elementFiValueProviderFactoryMock),
            address(notionalValueProviderFactoryMock),
            address(yieldValueProviderFactoryMock),
            address(chainlinkValueProviderFactoryMock),
            address(aggregatorOracleFactoryMock),
            address(relayerFactoryMock)
        );
    }

    function test_deploy() public {
        // Check the factory addresses are properly set
        assertEq(
            factory.elementFiValueProviderFactory(),
            address(elementFiValueProviderFactoryMock),
            "Invalid elementFiValueProviderFactoryMock"
        );

        assertEq(
            factory.notionalValueProviderFactory(),
            address(notionalValueProviderFactoryMock),
            "Invalid notionalFiValueProviderFactory"
        );

        assertEq(
            factory.yieldValueProviderFactory(),
            address(yieldValueProviderFactoryMock),
            "Invalid yieldValueProviderFactory"
        );

        assertEq(
            factory.chainlinkValueProviderFactory(),
            address(chainlinkValueProviderFactoryMock),
            "Invalid chainLinkValueProviderFactory"
        );

        assertEq(
            factory.aggregatorOracleFactory(),
            address(aggregatorOracleFactoryMock),
            "Invalid aggregatorOracleFactory"
        );

        assertEq(
            factory.relayerFactory(),
            address(relayerFactoryMock),
            "Invalid relayerFactory"
        );
    }

    function test_setPermission_CallsAllowCaller_WithCorrectArguments(
        bytes32 sig_,
        address who_
    ) public {
        // Define arguments
        MockProvider where = new MockProvider();

        // Call factory to set permission
        factory.setPermission(address(where), sig_, who_);

        // Check the destination was called correctly by the factory
        MockProvider.CallData memory cd = where.getCallData(0);
        assertEq(cd.caller, address(factory));
        assertEq(cd.functionSelector, Guarded.allowCaller.selector);
        assertEq(
            keccak256(cd.data),
            keccak256(
                abi.encodeWithSelector(Guarded.allowCaller.selector, sig_, who_)
            )
        );
    }

    function test_UnauthorizedUser_CannotSetPermission(
        address where_,
        bytes32 sig_,
        address who_
    ) public {
        // Create user
        Caller user = new Caller();

        // Call factory to set permission
        (bool ok, ) = user.externalCall(
            address(factory),
            abi.encodeWithSelector(
                factory.setPermission.selector,
                address(where_),
                sig_,
                who_
            )
        );

        // Call should be unsuccessful
        assertTrue(
            ok == false,
            "Unauthorized user should not be allowed to call `setPermission`"
        );
    }

    function test_AuthorizedUser_CanSetPermission(bytes32 sig_, address who_)
        public
    {
        // Create mock
        MockProvider where = new MockProvider();

        // Create user
        Caller user = new Caller();

        // Authorize user
        factory.allowCaller(factory.setPermission.selector, address(user));

        // User calls factory to set permission
        (bool ok, ) = user.externalCall(
            address(factory),
            abi.encodeWithSelector(
                factory.setPermission.selector,
                address(where),
                sig_,
                who_
            )
        );

        // Call should be successful
        assertTrue(
            ok,
            "Authorized user should be allowed to call `setPermission`"
        );
    }

    function test_removePermission_CallsBlockCaller_WithCorrectArguments(
        bytes32 sig_,
        address who_
    ) public {
        // Create mock to check correct call
        MockProvider where = new MockProvider();

        // Call factory to remove permission
        factory.removePermission(address(where), sig_, who_);

        // Check the destination was called correctly by the factory
        MockProvider.CallData memory cd = where.getCallData(0);
        assertEq(cd.caller, address(factory));
        assertEq(cd.functionSelector, Guarded.blockCaller.selector);
        assertEq(
            keccak256(cd.data),
            keccak256(
                abi.encodeWithSelector(Guarded.blockCaller.selector, sig_, who_)
            )
        );
    }

    function test_UnauthorizedUser_CannotRemovePermission(
        bytes32 sig_,
        address who_
    ) public {
        // Create mock
        MockProvider where = new MockProvider();

        // Create user
        Caller user = new Caller();

        // Call factory to remove permission
        (bool ok, ) = user.externalCall(
            address(factory),
            abi.encodeWithSelector(
                factory.removePermission.selector,
                address(where),
                sig_,
                who_
            )
        );

        // Call should be unsuccessful
        assertTrue(
            ok == false,
            "Unauthorized user should not be able to call `removePermission`"
        );
    }

    function test_AuthorizedUser_CanRemovePermission(bytes32 sig_, address who_)
        public
    {
        // Create mock
        MockProvider where = new MockProvider();

        // Create user
        Caller user = new Caller();

        // Authorize user
        factory.allowCaller(factory.removePermission.selector, address(user));

        // User calls factory to remove permission
        (bool ok, ) = user.externalCall(
            address(factory),
            abi.encodeWithSelector(
                factory.removePermission.selector,
                address(where),
                sig_,
                who_
            )
        );

        // Call should be successful
        assertTrue(
            ok,
            "Authorized user should be allowed to call `removePermission`"
        );
    }

    function test_deploy_elementFiValueProvider() public {
        // Create the oracle data structure
        ElementVPData memory elementValueProvider = createElementVPData();
        OracleData memory elementDataOracle = OracleData({
            valueProviderData: abi.encode(elementValueProvider),
            timeWindow: 100,
            maxValidTime: 300,
            alpha: 2 * 10**17,
            valueProviderType: uint8(Factory.ValueProviderType.Element)
        });

        address oracleAddress = factory.deployElementFiValueProvider(
            elementDataOracle
        );

        // Make sure the Oracle was deployed
        assertTrue(
            oracleAddress != address(0),
            "Element Oracle should be correctly deployed"
        );
    }

    function test_deploy_elementFiValueProvider_onlyAuthorizedUsers() public {
        // Create the oracle data structure
        ElementVPData memory elementValueProvider = createElementVPData();
        OracleData memory elementDataOracle = OracleData({
            valueProviderData: abi.encode(elementValueProvider),
            timeWindow: 100,
            maxValidTime: 300,
            alpha: 2 * 10**17,
            valueProviderType: uint8(Factory.ValueProviderType.Element)
        });

        // Create a new caller for the external call
        Caller user = new Caller();

        // Call deployElementFiValueProvider
        (bool ok, ) = user.externalCall(
            address(factory),
            abi.encodeWithSelector(
                factory.deployElementFiValueProvider.selector,
                elementDataOracle
            )
        );
        assertTrue(
            ok == false,
            "Only authorized users should be able to deploy oracles"
        );
    }

    function test_deploy_notionalFinanceValueProvider() public {
        // Create the oracle data structure
        NotionalVPData memory notionalValueProvider = createNotionalVPData();
        OracleData memory notionalDataOracle = OracleData({
            valueProviderData: abi.encode(notionalValueProvider),
            timeWindow: 100,
            maxValidTime: 300,
            alpha: 2 * 10**17,
            valueProviderType: uint8(Factory.ValueProviderType.Notional)
        });

        // Deploy the oracle
        address oracleAddress = factory.deployNotionalFinanceValueProvider(
            notionalDataOracle
        );

        // Make sure the Oracle was deployed
        assertTrue(
            oracleAddress != address(0),
            "Notional Oracle should be correctly deployed"
        );
    }

    function test_deploy_notionalFinanceValueProvider_onlyAuthorizedUsers()
        public
    {
        // Create the oracle data structure
        NotionalVPData memory notionalValueProvider = createNotionalVPData();
        OracleData memory notionalDataOracle = OracleData({
            valueProviderData: abi.encode(notionalValueProvider),
            timeWindow: 100,
            maxValidTime: 300,
            alpha: 2 * 10**17,
            valueProviderType: uint8(Factory.ValueProviderType.Notional)
        });

        Caller user = new Caller();

        // Call deployNotionalFinanceValueProvider
        (bool ok, ) = user.externalCall(
            address(factory),
            abi.encodeWithSelector(
                factory.deployNotionalFinanceValueProvider.selector,
                notionalDataOracle
            )
        );
        assertTrue(
            ok == false,
            "Only authorized users should be able to deploy oracles"
        );
    }

    function test_deploy_yieldValueProvider() public {
        // Create the oracle data structure
        YieldVPData memory yieldValueProvider = createYieldVPData();
        OracleData memory yieldDataOracle = OracleData({
            valueProviderData: abi.encode(yieldValueProvider),
            timeWindow: 100,
            maxValidTime: 300,
            alpha: 2 * 10**17,
            valueProviderType: uint8(Factory.ValueProviderType.Yield)
        });

        address oracleAddress = factory.deployYieldValueProvider(
            yieldDataOracle
        );

        // Make sure the Oracle was deployed
        assertTrue(
            oracleAddress != address(0),
            "Yield Oracle should be correctly deployed"
        );
    }

    function test_deploy_yieldValueProvider_onlyAuthorizedUsers() public {
        // Create the oracle data structure
        YieldVPData memory yieldValueProvider = createYieldVPData();
        OracleData memory yieldDataOracle = OracleData({
            valueProviderData: abi.encode(yieldValueProvider),
            timeWindow: 100,
            maxValidTime: 300,
            alpha: 2 * 10**17,
            valueProviderType: uint8(Factory.ValueProviderType.Yield)
        });

        Caller user = new Caller();

        // Call deployYieldValueProvider
        (bool ok, ) = user.externalCall(
            address(factory),
            abi.encodeWithSelector(
                factory.deployYieldValueProvider.selector,
                yieldDataOracle
            )
        );
        assertTrue(
            ok == false,
            "Only authorized users should be able to deploy oracles"
        );
    }

    function test_deploy_chainlinkValueProvider() public {
        // Create the oracle data structure
        ChainlinkVPData memory chainlinkValueProvider = createChainlinkVPData();
        OracleData memory chainlinkDataOracle = OracleData({
            valueProviderData: abi.encode(chainlinkValueProvider),
            timeWindow: 100,
            maxValidTime: 300,
            alpha: 2 * 10**17,
            valueProviderType: uint8(Factory.ValueProviderType.Chainlink)
        });

        address oracleAddress = factory.deployChainlinkValueProvider(
            chainlinkDataOracle
        );

        // Make sure the Oracle was deployed
        assertTrue(
            oracleAddress != address(0),
            "Chainlink Oracle should be correctly deployed"
        );
    }

    function test_deploy_chainlinkValueProvider_onlyAuthorizedUsers() public {
        // Create the oracle data structure
        ChainlinkVPData memory chainlinkValueProvider = createChainlinkVPData();
        OracleData memory chainlinkDataOracle = OracleData({
            valueProviderData: abi.encode(chainlinkValueProvider),
            timeWindow: 100,
            maxValidTime: 300,
            alpha: 2 * 10**17,
            valueProviderType: uint8(Factory.ValueProviderType.Chainlink)
        });

        Caller user = new Caller();

        // Call deployChainlinkValueProvider
        (bool ok, ) = user.externalCall(
            address(factory),
            abi.encodeWithSelector(
                factory.deployChainlinkValueProvider.selector,
                chainlinkDataOracle
            )
        );
        assertTrue(
            ok == false,
            "Only authorized users should be able to deploy oracles"
        );
    }

    function test_deploy_aggregatorOracle_forEveryValueProviderType() public {
        // Setup an array of oracle data structures for every oracle type
        OracleData[] memory oracleData = new OracleData[](
            uint256(Factory.ValueProviderType.COUNT)
        );
        oracleData[
            uint256(Factory.ValueProviderType.Element)
        ] = createElementOracleData();
        oracleData[
            uint256(Factory.ValueProviderType.Notional)
        ] = createNotionalOracleData();
        oracleData[
            uint256(Factory.ValueProviderType.Yield)
        ] = createYieldOracleData();
        oracleData[
            uint256(Factory.ValueProviderType.Chainlink)
        ] = createChainlinkOracleData();

        // The test will fail if we add a value type and we do not implement a deploy method for it
        for (
            uint256 oracleType = 0;
            oracleType < uint256(Factory.ValueProviderType.COUNT);
            oracleType++
        ) {
            // Create a new mock aggregator and allow the factory to add oracles
            AggregatorOracle aggregatorOracle = new AggregatorOracle();
            aggregatorOracle.allowCaller(
                aggregatorOracle.ANY_SIG(),
                address(factory)
            );

            // Deploy and add the oracle to the aggregator oracle
            address oracleAddress = factory.deployAggregatorOracle(
                abi.encode(oracleData[oracleType]),
                address(aggregatorOracle)
            );

            // Check that oracleAdd was called on the aggregator
            assertTrue(
                aggregatorOracle.oracleExists(oracleAddress),
                "Deployed oracle should be contained by the aggregator oracle"
            );
        }
    }

    function test_deploy_aggregatorOracle_onlyAuthorizedUsers() public {
        OracleData memory oracleData = createElementOracleData();

        Caller user = new Caller();
        AggregatorOracle aggregatorOracle = new AggregatorOracle();
        aggregatorOracle.allowCaller(
            aggregatorOracle.ANY_SIG(),
            address(factory)
        );

        // Call deployAggregatorOracle
        (bool ok, ) = user.externalCall(
            address(factory),
            abi.encodeWithSelector(
                factory.deployAggregatorOracle.selector,
                abi.encode(oracleData),
                address(aggregatorOracle)
            )
        );

        assertTrue(
            ok == false,
            "Only authorized users should be able to call deployAggregatorOracle"
        );
    }

    function test_deploy_aggregator_forEveryCompatibleValueProvider() public {
        // Deploy discount rate aggregators for every value provider type
        for (
            uint256 oracleType = 0;
            oracleType < uint256(Factory.ValueProviderType.COUNT);
            oracleType++
        ) {
            Relayer relayer = new Relayer(
                address(0xc011b005),
                IRelayer.RelayerType.DiscountRate
            );

            relayer.allowCaller(relayer.ANY_SIG(), address(factory));

            // Create mock data and deploy the aggregator
            address aggregatorAddress = factory.deployAggregator(
                abi.encode(
                    createDiscountRateAggregatorData(
                        Factory.ValueProviderType(oracleType),
                        oracleType
                    )
                ),
                address(relayer)
            );

            assertTrue(
                aggregatorAddress != address(0),
                "Aggregator not deployed"
            );
        }
    }

    function test_deploy_aggregator_checkExistenceOfOracles() public {
        // Create a mock discount rate relayer
        Relayer relayer = new Relayer(
            address(0xc011b005),
            IRelayer.RelayerType.DiscountRate
        );

        relayer.allowCaller(relayer.ANY_SIG(), address(factory));

        // Create an aggregator with multiple oracles
        uint256 oracleCount = 3;
        AggregatorData memory aggregator = AggregatorData({
            encodedTokenId: bytes32(uint256(1)),
            oracleData: new bytes[](oracleCount),
            requiredValidValues: 1,
            minimumPercentageDeltaValue: 1
        });

        for (
            uint256 oracleIndex = 0;
            oracleIndex < oracleCount;
            oracleIndex++
        ) {
            aggregator.oracleData[oracleIndex] = abi.encode(
                createElementOracleData()
            );
        }

        // Deploy the aggregator
        address aggregatorAddress = factory.deployAggregator(
            abi.encode(aggregator),
            address(relayer)
        );

        // Check that all the oracles where added
        assertEq(
            IAggregatorOracle(aggregatorAddress).oracleCount(),
            oracleCount,
            "Invalid Aggregator oracle count"
        );
    }

    function test_deploy_aggregator_checkValidValues() public {
        Relayer relayer = new Relayer(
            address(0xc011b005),
            IRelayer.RelayerType.DiscountRate
        );

        relayer.allowCaller(relayer.ANY_SIG(), address(factory));

        // Create the mock Discount rate aggregator data
        uint256 validValues = 1;
        AggregatorData memory aggregator = AggregatorData({
            encodedTokenId: bytes32(uint256(1)),
            oracleData: new bytes[](1),
            requiredValidValues: validValues,
            minimumPercentageDeltaValue: 1
        });

        aggregator.oracleData[0] = abi.encode(createElementOracleData());

        // Deploy the aggregator
        address aggregatorAddress = factory.deployAggregator(
            abi.encode(aggregator),
            address(relayer)
        );

        // Check that the required valid values is correct
        assertEq(
            AggregatorOracle(aggregatorAddress).requiredValidValues(),
            validValues,
            "Invalid required valid values"
        );
    }

    function test_deploy_aggregator_onlyAuthorizedUsers() public {
        Caller user = new Caller();
        Relayer relayer = new Relayer(
            address(0xc011b005),
            IRelayer.RelayerType.DiscountRate
        );

        relayer.allowCaller(relayer.ANY_SIG(), address(factory));

        // Create the discount rate aggregator data
        AggregatorData memory aggregator = AggregatorData({
            encodedTokenId: bytes32(uint256(1)),
            oracleData: new bytes[](1),
            requiredValidValues: 1,
            minimumPercentageDeltaValue: 1
        });

        aggregator.oracleData[0] = abi.encode(createElementOracleData());

        // Call deployDiscountRateAggregator
        (bool ok, ) = user.externalCall(
            address(factory),
            abi.encodeWithSelector(
                factory.deployAggregator.selector,
                abi.encode(aggregator),
                address(relayer)
            )
        );

        assertTrue(
            ok == false,
            "Only authorized users should be able to call deployAggregator"
        );
    }

    function test_deploy_relayer_discountRate_createsContract() public {
        address collybus = address(0xC0111b005);
        address relayer = factory.deployRelayer(
            collybus,
            IRelayer.RelayerType.DiscountRate
        );
        // Make sure the Relayer was deployed
        assertTrue(
            relayer != address(0),
            "Discount Rate Relayer should be deployed"
        );
    }

    function test_deploy_relayer_spotPrice_createsContract() public {
        address collybus = address(0xC01115107);
        address relayer = factory.deployRelayer(
            collybus,
            IRelayer.RelayerType.SpotPrice
        );

        // Make sure the Relayer_ was deployed
        assertTrue(
            relayer != address(0),
            "Spot Price Relayer should be deployed"
        );
    }

    function test_deploy_relayer_onlyAuthorizedUsers() public {
        Caller user = new Caller();
        address collybus = address(0xC0111b005);

        // Call deployCollybusDiscountRateRelayer
        (bool ok, ) = user.externalCall(
            address(factory),
            abi.encodeWithSelector(
                factory.deployRelayer.selector,
                collybus,
                IRelayer.RelayerType.DiscountRate
            )
        );

        assertTrue(
            ok == false,
            "Only authorized users should be able to deploy Relayers"
        );
    }

    function test_deploy_collybusDiscountRateArchitecture() public {
        RelayerDeployData memory deployData = createDiscountRateDeployData();

        // Deploy the oracle architecture
        address relayer = factory.deployDiscountRateArchitecture(
            abi.encode(deployData),
            address(0x1234)
        );

        // Check the creation of the discount rate relayer
        assertTrue(
            relayer != address(0),
            "CollybusDiscountPriceRelayer should be deployed"
        );

        // Check that all aggregators were added to the relayer
        assertEq(
            IRelayer(relayer).oracleCount(),
            deployData.aggregatorData.length,
            "Discount rate relayer invalid aggregator count"
        );
    }

    function test_deploy_collybusDiscountRateArchitecture_onlyAuthorizedUsers()
        public
    {
        Caller user = new Caller();
        RelayerDeployData memory deployData = createDiscountRateDeployData();

        // Call deployDiscountRateArchitecture
        (bool ok, ) = user.externalCall(
            address(factory),
            abi.encodeWithSelector(
                factory.deployDiscountRateArchitecture.selector,
                abi.encode(deployData),
                address(0x1234)
            )
        );

        assertTrue(
            ok == false,
            "Only authorized users should be able to call deployDiscountRateArchitecture"
        );
    }

    function test_addAggregator() public {
        RelayerDeployData memory deployData = createDiscountRateDeployData();

        // Deploy the oracle architecture
        address relayer = factory.deployDiscountRateArchitecture(
            abi.encode(deployData),
            address(0x1234)
        );

        // Save the current aggregator count in the Relayer
        uint256 aggregatorCount = IRelayer(relayer).oracleCount();

        // Create the Aggregator data structure that will contain a Notional Oracle
        // Use the aggregator count as token id to make sure it is unused
        AggregatorData memory notionalAggregator = AggregatorData({
            encodedTokenId: bytes32(uint256(aggregatorCount)),
            oracleData: new bytes[](1),
            requiredValidValues: 1,
            minimumPercentageDeltaValue: 1
        });

        notionalAggregator.oracleData[0] = abi.encode(
            createNotionalOracleData()
        );

        // Deploy the new aggregator
        address aggregatorAddress = factory.deployAggregator(
            abi.encode(notionalAggregator),
            relayer
        );

        // The Relayer should contain an extra Aggregator/Oracle
        assertEq(
            aggregatorCount + 1,
            IRelayer(relayer).oracleCount(),
            "Relayer should contain the new aggregator"
        );

        // The Relayer should contain the new aggregator
        assertTrue(
            IRelayer(relayer).oracleExists(aggregatorAddress),
            "Aggregator should exist"
        );
    }

    function test_addOracle() public {
        RelayerDeployData memory deployData = createDiscountRateDeployData();

        // Deploy the oracle architecture
        address relayer = factory.deployDiscountRateArchitecture(
            abi.encode(deployData),
            address(0x1234)
        );

        // Get the address of the first aggregator
        address firstAggregatorAddress = IRelayer(relayer).oracleAt(0);

        // Cache the number of oracles in the aggregator
        uint256 oracleCount = IAggregatorOracle(firstAggregatorAddress)
            .oracleCount();

        // Create and add the oracle to the aggregator
        address oracleAddress = factory.deployAggregatorOracle(
            abi.encode(createNotionalOracleData()),
            firstAggregatorAddress
        );

        // The aggregator should contain an extra Oracle
        assertEq(
            oracleCount + 1,
            IAggregatorOracle(firstAggregatorAddress).oracleCount(),
            "Aggregator should contain an extra Oracle"
        );

        assertTrue(
            IAggregatorOracle(firstAggregatorAddress).oracleExists(
                oracleAddress
            ),
            "Aggregator should contain the added Oracle"
        );
    }

    function test_deploy_collybusSpotPriceArchitecture() public {
        RelayerDeployData memory deployData = createSpotPriceDeployData();

        // Deploy the oracle architecture
        address relayer = factory.deploySpotPriceArchitecture(
            abi.encode(deployData),
            address(0x1234)
        );

        // Check the creation of the discount rate relayer
        assertTrue(
            relayer != address(0),
            "CollybusSpotPriceRelayer should be deployed"
        );

        assertEq(
            IRelayer(relayer).oracleCount(),
            deployData.aggregatorData.length,
            "CollybusSpotPriceRelayer invalid aggregator count"
        );
    }

    function test_deploy_collybusSpotPriceArchitecture_onlyAuthorizedUsers()
        public
    {
        Caller user = new Caller();
        RelayerDeployData memory deployData = createSpotPriceDeployData();

        // Call deploySpotPriceArchitecture
        (bool ok, ) = user.externalCall(
            address(factory),
            abi.encodeWithSelector(
                factory.deploySpotPriceArchitecture.selector,
                abi.encode(deployData),
                address(0x1234)
            )
        );

        assertTrue(
            ok == false,
            "Only authorized users should be able to call deploySpotPriceArchitecture"
        );
    }

    function createElementVPData() internal returns (ElementVPData memory) {
        // Set-up the needed parameters to create the ElementFi Value Provider.
        // Values used are the same as in the ElementFiValueProvider test.
        // We need to mock the decimal values for the tokens because they are
        // interrogated when the contract is created.
        MockProvider underlierMock = new MockProvider();
        underlierMock.givenQueryReturnResponse(
            abi.encodeWithSelector(ERC20.decimals.selector),
            MockProvider.ReturnData({
                success: true,
                data: abi.encode(uint8(18))
            }),
            false
        );

        MockProvider ePTokenBondMock = new MockProvider();
        ePTokenBondMock.givenQueryReturnResponse(
            abi.encodeWithSelector(ERC20.decimals.selector),
            MockProvider.ReturnData({
                success: true,
                data: abi.encode(uint8(18))
            }),
            false
        );

        MockProvider poolTokenMock = new MockProvider();
        poolTokenMock.givenQueryReturnResponse(
            abi.encodeWithSelector(ERC20.decimals.selector),
            MockProvider.ReturnData({
                success: true,
                data: abi.encode(uint8(18))
            }),
            false
        );

        ElementVPData memory elementValueProvider = ElementVPData({
            poolId: 0x6dd0f7c8f4793ed2531c0df4fea8633a21fdcff40002000000000000000000b7,
            balancerVault: address(0x12345),
            poolToken: address(poolTokenMock),
            underlier: address(underlierMock),
            ePTokenBond: address(ePTokenBondMock),
            timeScale: 2426396518,
            maturity: 1651275535
        });

        return elementValueProvider;
    }

    function createNotionalVPData()
        public
        pure
        returns (NotionalVPData memory)
    {
        NotionalVPData memory notionalValueProvider = NotionalVPData({
            notionalViewAddress: 0x1344A36A1B56144C3Bc62E7757377D288fDE0369,
            currencyId: 2,
            lastImpliedRateDecimals: 9,
            maturityDate: 1671840000,
            settlementDate: 1648512000
        });
        return notionalValueProvider;
    }

    function createYieldVPData() internal returns (YieldVPData memory) {
        // Mock the yield pool that is needed when the value provider contract is created
        MockProvider yieldPool = new MockProvider();

        yieldPool.givenQueryReturnResponse(
            abi.encodeWithSelector(IYieldPool.getCache.selector),
            MockProvider.ReturnData({
                success: true,
                data: abi.encode(uint112(0), uint112(0), uint32(0))
            }),
            false
        );

        yieldPool.givenQueryReturnResponse(
            abi.encodeWithSelector(IYieldPool.cumulativeBalancesRatio.selector),
            MockProvider.ReturnData({
                success: true,
                data: abi.encode(uint256(0))
            }),
            false
        );

        YieldVPData memory yieldValueProviderData = YieldVPData({
            poolAddress: address(yieldPool),
            maturity: 1648177200,
            timeScale: 3168808781
        });

        return yieldValueProviderData;
    }

    function createElementOracleData() internal returns (OracleData memory) {
        return
            OracleData({
                valueProviderData: abi.encode(createElementVPData()),
                timeWindow: 0,
                maxValidTime: 0,
                alpha: 1,
                valueProviderType: uint8(Factory.ValueProviderType.Element)
            });
    }

    function createNotionalOracleData()
        internal
        pure
        returns (OracleData memory)
    {
        return
            OracleData({
                valueProviderData: abi.encode(createNotionalVPData()),
                timeWindow: 0,
                maxValidTime: 0,
                alpha: 1,
                valueProviderType: uint8(Factory.ValueProviderType.Notional)
            });
    }

    function createYieldOracleData() internal returns (OracleData memory) {
        return
            OracleData({
                valueProviderData: abi.encode(createYieldVPData()),
                timeWindow: 0,
                maxValidTime: 0,
                alpha: 1,
                valueProviderType: uint8(Factory.ValueProviderType.Yield)
            });
    }

    function createChainlinkOracleData() internal returns (OracleData memory) {
        return
            OracleData({
                valueProviderData: abi.encode(createChainlinkVPData()),
                timeWindow: 0,
                maxValidTime: 0,
                alpha: 1,
                valueProviderType: uint8(Factory.ValueProviderType.Chainlink)
            });
    }

    function createChainlinkVPData() internal returns (ChainlinkVPData memory) {
        // Set-up the needed parameters to create the Chainlink Value Provider.
        // We need to mock the decimal getter because it's interrogated when the contract is created.
        MockProvider chainlinkMock = new MockProvider();
        chainlinkMock.givenQueryReturnResponse(
            abi.encodeWithSelector(
                IChainlinkAggregatorV3Interface.decimals.selector
            ),
            MockProvider.ReturnData({
                success: true,
                data: abi.encode(uint8(8))
            }),
            false
        );

        ChainlinkVPData memory chainlinkValueProvider = ChainlinkVPData({
            chainlinkAggregatorAddress: address(chainlinkMock)
        });

        return chainlinkValueProvider;
    }

    function createDiscountRateAggregatorData(
        Factory.ValueProviderType valueType_,
        uint256 tokenId_
    ) internal returns (AggregatorData memory) {
        // Create a discount rate aggregator for a certain given value provider
        AggregatorData memory aggregator = AggregatorData({
            encodedTokenId: bytes32(tokenId_),
            oracleData: new bytes[](1),
            requiredValidValues: 1,
            minimumPercentageDeltaValue: 1
        });

        // Create the oracle data structure based on the provided value provider type
        if (valueType_ == Factory.ValueProviderType.Element) {
            aggregator.oracleData[0] = abi.encode(createElementOracleData());
        } else if (valueType_ == Factory.ValueProviderType.Notional) {
            aggregator.oracleData[0] = abi.encode(createNotionalOracleData());
        } else if (valueType_ == Factory.ValueProviderType.Yield) {
            aggregator.oracleData[0] = abi.encode(createYieldOracleData());
        } else if (valueType_ == Factory.ValueProviderType.Chainlink) {
            aggregator.oracleData[0] = abi.encode(createChainlinkOracleData());
        } else {
            revert FactoryTest__invalidDiscountRateAggregatorType(
                uint256(valueType_)
            );
        }

        return aggregator;
    }

    function createSpotPriceAggregatorData(
        Factory.ValueProviderType valueType_,
        address tokenAddress_
    ) internal returns (AggregatorData memory) {
        // Create a spot price aggregator for a certain given value provider
        AggregatorData memory aggregator = AggregatorData({
            encodedTokenId: bytes32(uint256(uint160(tokenAddress_))),
            oracleData: new bytes[](1),
            requiredValidValues: 1,
            minimumPercentageDeltaValue: 1
        });

        // Create the oracle data structure based on the provided value provider type
        if (valueType_ == Factory.ValueProviderType.Element) {
            aggregator.oracleData[0] = abi.encode(createElementOracleData());
        } else if (valueType_ == Factory.ValueProviderType.Notional) {
            aggregator.oracleData[0] = abi.encode(createNotionalOracleData());
        } else if (valueType_ == Factory.ValueProviderType.Yield) {
            aggregator.oracleData[0] = abi.encode(createYieldOracleData());
        } else if (valueType_ == Factory.ValueProviderType.Chainlink) {
            aggregator.oracleData[0] = abi.encode(createChainlinkOracleData());
        } else {
            revert FactoryTest__invalidDiscountRateAggregatorType(
                uint256(valueType_)
            );
        }

        return aggregator;
    }

    function createDiscountRateDeployData()
        internal
        returns (RelayerDeployData memory)
    {
        // Create the data structure for a full discount rate relayer architecture with multiple oracles and aggregators
        RelayerDeployData memory deployData;
        deployData.aggregatorData = new bytes[](
            uint256(Factory.ValueProviderType.COUNT)
        );
        for (
            uint256 oracleType = 0;
            oracleType < uint256(Factory.ValueProviderType.COUNT);
            oracleType++
        ) {
            // use the oracle type as index for the aggregator data structure
            // use the oracle type as a unique token Id for each aggregator
            deployData.aggregatorData[oracleType] = abi.encode(
                createDiscountRateAggregatorData(
                    Factory.ValueProviderType(oracleType),
                    oracleType
                )
            );
        }

        return deployData;
    }

    function createSpotPriceDeployData()
        internal
        returns (RelayerDeployData memory)
    {
        // Create the data structure for a full spot price relayer architecture with multiple oracles and aggregators
        RelayerDeployData memory deployData;
        deployData.aggregatorData = new bytes[](
            uint256(Factory.ValueProviderType.COUNT)
        );

        // Compute the token address as a uint160 which will be inc after every add
        address tokenAddress = address(uint160(1));
        for (
            uint256 oracleType = 0;
            oracleType < uint256(Factory.ValueProviderType.COUNT);
            oracleType++
        ) {
            // use the oracle type as index for the aggregator data structure
            deployData.aggregatorData[oracleType] = abi.encode(
                createSpotPriceAggregatorData(
                    Factory.ValueProviderType(oracleType),
                    tokenAddress
                )
            );
            tokenAddress = address(uint160(tokenAddress) + 1);
        }

        return deployData;
    }
}
*/
