// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import "ds-test/test.sol";
import {Hevm} from "src/test/utils/Hevm.sol";
import {Caller} from "src/test/utils/Caller.sol";
import {MockProvider} from "@cleanunicorn/mockprovider/src/MockProvider.sol";

import "src/factory/Factory.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Guarded} from "src/guarded/Guarded.sol";
import {Oracle} from "src/oracle/Oracle.sol";
import {AggregatorOracle} from "src/aggregator/AggregatorOracle.sol";

// Relayers
import {ICollybusDiscountRateRelayer} from "src/relayer/CollybusDiscountRate/ICollybusDiscountRateRelayer.sol";
import {CollybusDiscountRateRelayer} from "src/relayer/CollybusDiscountRate/CollybusDiscountRateRelayer.sol";

import {ICollybusSpotPriceRelayer} from "src/relayer/CollybusSpotPrice/ICollybusSpotPriceRelayer.sol";
import {CollybusSpotPriceRelayer} from "src/relayer/CollybusSpotPrice/CollybusSpotPriceRelayer.sol";

import {IChainlinkAggregatorV3Interface} from "src/oracle_implementations/spot_price/Chainlink/ChainlinkAggregatorV3Interface.sol";

contract FactoryTest is DSTest {

    error FactoryTest__invalidDiscountRateAggregatorType(uint valueType);
    error FactoryTest__invalidSpotPriceAggregatorType(uint valueType);

    Factory internal factory;

    MockProvider internal elementFiValueProviderFactoryMock;
    MockProvider internal notionalValueProviderFactoryMock;
    MockProvider internal yieldValueProviderFactoryMock;
    MockProvider internal chainlinkValueProviderFactoryMock;
    MockProvider internal aggregatorOracleFactoryMock;
    MockProvider internal collybusDiscountRateRelayerFactoryMock;
    MockProvider internal collybusSpotPriceRelayerFactoryMock;

    function setUp() public {
        elementFiValueProviderFactoryMock = new MockProvider();
        notionalValueProviderFactoryMock = new MockProvider();
        yieldValueProviderFactoryMock = new MockProvider();
        chainlinkValueProviderFactoryMock = new MockProvider();
        aggregatorOracleFactoryMock = new MockProvider();
        collybusDiscountRateRelayerFactoryMock = new MockProvider();
        collybusSpotPriceRelayerFactoryMock = new MockProvider();

        address mockReturnAddress = address(0x110c5);
        // Define fallback methods for each value provider factory
        // Test that need specific data will add proper queries
        elementFiValueProviderFactoryMock.setDefaultResponse(
            MockProvider.ReturnData({
                success: true,
                data: abi.encode(mockReturnAddress)
            })
        );

        notionalValueProviderFactoryMock.setDefaultResponse(
            MockProvider.ReturnData({
                success: true,
                data: abi.encode(mockReturnAddress)
            })
        );

        yieldValueProviderFactoryMock.setDefaultResponse(
            MockProvider.ReturnData({
                success: true,
                data: abi.encode(mockReturnAddress)
            })
        );

        chainlinkValueProviderFactoryMock.setDefaultResponse(
            MockProvider.ReturnData({
                success: true,
                data: abi.encode(mockReturnAddress)
            })
        );

        aggregatorOracleFactoryMock.setDefaultResponse(
            MockProvider.ReturnData({
                success: true,
                data: abi.encode(mockReturnAddress)
            })
        );

        collybusDiscountRateRelayerFactoryMock.setDefaultResponse(
            MockProvider.ReturnData({
                success: true,
                data: abi.encode(mockReturnAddress)
            })
        );

        collybusSpotPriceRelayerFactoryMock.setDefaultResponse(
            MockProvider.ReturnData({
                success: true,
                data: abi.encode(mockReturnAddress)
            })
        );

        factory = new Factory(
            address(elementFiValueProviderFactoryMock),
            address(notionalValueProviderFactoryMock),
            address(yieldValueProviderFactoryMock),
            address(chainlinkValueProviderFactoryMock),
            address(aggregatorOracleFactoryMock),
            address(collybusDiscountRateRelayerFactoryMock),
            address(collybusSpotPriceRelayerFactoryMock)
        );
    }

    function test_deploy() public {
        // Check the factory addresses are properly set
        assertEq(
            factory.elementFiValueProviderFactory(),
            address(elementFiValueProviderFactoryMock),
            "Invalid elementFiValueProviderFactory"
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
            factory.collybusDiscountRateRelayerFactory(),
            address(collybusDiscountRateRelayerFactoryMock),
            "Invalid collybusDiscountRateRelayerFactory"
        );

        assertEq(
            factory.collybusSpotPriceRelayerFactory(),
            address(collybusSpotPriceRelayerFactoryMock),
            "Invalid collybusSpotPriceRelayerFactory"
        );
    }

    function test_deploy_ElementFiValueProvider() public {
        // Create the oracle data structure
        ElementVPData memory elementValueProvider = createElementVPData();
        OracleData memory elementDataOracle = OracleData({
            valueProviderData: abi.encode(elementValueProvider),
            timeWindow: 100,
            maxValidTime: 300,
            alpha: 2 * 10**17,
            valueProviderType: uint8(Factory.ValueProviderType.Element)
        });
        // Set-up the mock providers
        address mockOracleAddress = address(0x110C0);
        elementFiValueProviderFactoryMock.givenQueryReturnResponse(
            abi.encodeWithSelector(
                IFactoryElementFiValueProvider.create.selector,
                elementDataOracle.timeWindow,
                elementDataOracle.maxValidTime,
                elementDataOracle.alpha,
                elementValueProvider.poolId,
                elementValueProvider.balancerVault,
                elementValueProvider.poolToken,
                elementValueProvider.underlier,
                elementValueProvider.ePTokenBond,
                elementValueProvider.timeScale,
                elementValueProvider.maturity
            ),
            MockProvider.ReturnData({
                success: true,
                data: abi.encode(mockOracleAddress)
            }),
            false
        );

        address oracleAddress = factory.deployElementFiValueProvider(
            elementDataOracle
        );

        // Make sure the Oracle was deployed
        assertTrue(
            oracleAddress == mockOracleAddress,
            "Element Oracle should be correctly deployed"
        );
    }

    function test_deploy_ElementFiValueProvider_OnlyAuthrorizedUsers() public {
        // Create the oracle data structure
        ElementVPData memory elementValueProvider = createElementVPData();
        OracleData memory elementDataOracle = OracleData({
            valueProviderData: abi.encode(elementValueProvider),
            timeWindow: 100,
            maxValidTime: 300,
            alpha: 2 * 10**17,
            valueProviderType: uint8(Factory.ValueProviderType.Element)
        });
        // Set-up the mock providers
        address mockOracleAddress = address(0x110C0);
        elementFiValueProviderFactoryMock.givenQueryReturnResponse(
            abi.encodeWithSelector(
                IFactoryElementFiValueProvider.create.selector,
                elementDataOracle.timeWindow,
                elementDataOracle.maxValidTime,
                elementDataOracle.alpha,
                elementValueProvider.poolId,
                elementValueProvider.balancerVault,
                elementValueProvider.poolToken,
                elementValueProvider.underlier,
                elementValueProvider.ePTokenBond,
                elementValueProvider.timeScale,
                elementValueProvider.maturity
            ),
            MockProvider.ReturnData({
                success: true,
                data: abi.encode(mockOracleAddress)
            }),
            false
        );

        Caller user = new Caller();

        // Deploy the oracle
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

    function test_deploy_NotionalFinanceValueProvider() public {
        // Create the oracle data structure
        NotionalVPData memory notionalValueProvider = createNotionalVPData();
        OracleData memory notionalDataOracle = OracleData({
            valueProviderData: abi.encode(notionalValueProvider),
            timeWindow: 100,
            maxValidTime: 300,
            alpha: 2 * 10**17,
            valueProviderType: uint8(Factory.ValueProviderType.Notional)
        });
        // Set-up the mock providers
        address mockOracleAddress = address(0x110C0);
        notionalValueProviderFactoryMock.givenQueryReturnResponse(
            abi.encodeWithSelector(
                IFactoryNotionalFinanceValueProvider.create.selector,
                notionalDataOracle.timeWindow,
                notionalDataOracle.maxValidTime,
                notionalDataOracle.alpha,
                notionalValueProvider.notionalViewAddress,
                notionalValueProvider.currencyId,
                notionalValueProvider.lastImpliedRateDecimals,
                notionalValueProvider.maturityDate,
                notionalValueProvider.settlementDate
            ),
            MockProvider.ReturnData({
                success: true,
                data: abi.encode(mockOracleAddress)
            }),
            false
        );

        address oracleAddress = factory.deployNotionalFinanceValueProvider(
            notionalDataOracle
        );

        // Make sure the Oracle was deployed
        assertTrue(
            oracleAddress == mockOracleAddress,
            "Notional Oracle should be correctly deployed"
        );
    }

    function test_deploy_NotionalFinanceValueProvider_OnlyAuthrorizedUsers()
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
        // Set-up the mock providers
        address mockOracleAddress = address(0x110C0);
        notionalValueProviderFactoryMock.givenQueryReturnResponse(
            abi.encodeWithSelector(
                IFactoryNotionalFinanceValueProvider.create.selector,
                notionalDataOracle.timeWindow,
                notionalDataOracle.maxValidTime,
                notionalDataOracle.alpha,
                notionalValueProvider.notionalViewAddress,
                notionalValueProvider.currencyId,
                notionalValueProvider.lastImpliedRateDecimals,
                notionalValueProvider.maturityDate,
                notionalValueProvider.settlementDate
            ),
            MockProvider.ReturnData({
                success: true,
                data: abi.encode(mockOracleAddress)
            }),
            false
        );

        Caller user = new Caller();

        // Deploy the oracle
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

    function test_deploy_YieldValueProvider() public {
        // Create the oracle data structure
        YieldVPData memory yieldValueProvider = createYieldVPData();
        OracleData memory yieldDataOracle = OracleData({
            valueProviderData: abi.encode(yieldValueProvider),
            timeWindow: 100,
            maxValidTime: 300,
            alpha: 2 * 10**17,
            valueProviderType: uint8(Factory.ValueProviderType.Yield)
        });
        // Set-up the mock providers
        address mockOracleAddress = address(0x110C0);
        yieldValueProviderFactoryMock.givenQueryReturnResponse(
            abi.encodeWithSelector(
                IFactoryYieldValueProvider.create.selector,
                yieldDataOracle.timeWindow,
                yieldDataOracle.maxValidTime,
                yieldDataOracle.alpha,
                yieldValueProvider.poolAddress,
                yieldValueProvider.maturity,
                yieldValueProvider.timeScale
            ),
            MockProvider.ReturnData({
                success: true,
                data: abi.encode(mockOracleAddress)
            }),
            false
        );

        address oracleAddress = factory.deployYieldValueProvider(
            yieldDataOracle
        );

        // Make sure the Oracle was deployed
        assertTrue(
            oracleAddress == mockOracleAddress,
            "Yield Oracle should be correctly deployed"
        );
    }

    function test_deploy_YieldValueProvider_OnlyAuthrorizedUsers() public {
        // Create the oracle data structure
        YieldVPData memory yieldValueProvider = createYieldVPData();
        OracleData memory yieldDataOracle = OracleData({
            valueProviderData: abi.encode(yieldValueProvider),
            timeWindow: 100,
            maxValidTime: 300,
            alpha: 2 * 10**17,
            valueProviderType: uint8(Factory.ValueProviderType.Yield)
        });
        // Set-up the mock providers
        address mockOracleAddress = address(0x110C0);
        yieldValueProviderFactoryMock.givenQueryReturnResponse(
            abi.encodeWithSelector(
                IFactoryYieldValueProvider.create.selector,
                yieldDataOracle.timeWindow,
                yieldDataOracle.maxValidTime,
                yieldDataOracle.alpha,
                yieldValueProvider.poolAddress,
                yieldValueProvider.maturity,
                yieldValueProvider.timeScale
            ),
            MockProvider.ReturnData({
                success: true,
                data: abi.encode(mockOracleAddress)
            }),
            false
        );

        Caller user = new Caller();

        // Deploy the oracle
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

    function test_deploy_ChainlinkValueProvider() public {
        // Create the oracle data structure
        ChainlinkVPData memory chainlinkValueProvider = createChainlinkVPData();
        OracleData memory chainlinkDataOracle = OracleData({
            valueProviderData: abi.encode(chainlinkValueProvider),
            timeWindow: 100,
            maxValidTime: 300,
            alpha: 2 * 10**17,
            valueProviderType: uint8(Factory.ValueProviderType.Chainlink)
        });
        // Set-up the mock providers
        address mockOracleAddress = address(0x110C0);
        chainlinkValueProviderFactoryMock.givenQueryReturnResponse(
            abi.encodeWithSelector(
                IFactoryChainlinkValueProvider.create.selector,
                chainlinkDataOracle.timeWindow,
                chainlinkDataOracle.maxValidTime,
                chainlinkDataOracle.alpha,
                chainlinkValueProvider.chainlinkAggregatorAddress
            ),
            MockProvider.ReturnData({
                success: true,
                data: abi.encode(mockOracleAddress)
            }),
            false
        );

        address oracleAddress = factory.deployChainlinkValueProvider(
            chainlinkDataOracle
        );

        // Make sure the Oracle was deployed
        assertTrue(
            oracleAddress == mockOracleAddress,
            "Chainlink Oracle should be correctly deployed"
        );
    }

    function test_deploy_ChainlinkValueProvider_OnlyAuthrorizedUsers() public {
        // Create the oracle data structure
        ChainlinkVPData memory chainlinkValueProvider = createChainlinkVPData();
        OracleData memory chainlinkDataOracle = OracleData({
            valueProviderData: abi.encode(chainlinkValueProvider),
            timeWindow: 100,
            maxValidTime: 300,
            alpha: 2 * 10**17,
            valueProviderType: uint8(Factory.ValueProviderType.Chainlink)
        });
        // Set-up the mock providers
        address mockOracleAddress = address(0x110C0);
        chainlinkValueProviderFactoryMock.givenQueryReturnResponse(
            abi.encodeWithSelector(
                IFactoryChainlinkValueProvider.create.selector,
                chainlinkDataOracle.timeWindow,
                chainlinkDataOracle.maxValidTime,
                chainlinkDataOracle.alpha,
                chainlinkValueProvider.chainlinkAggregatorAddress
            ),
            MockProvider.ReturnData({
                success: true,
                data: abi.encode(mockOracleAddress)
            }),
            false
        );

        Caller user = new Caller();

        // Deploy the oracle
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

    function test_deploy_AggregatorOracle_forEveryValueProviderType() public {
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

    function test_deploy_AggregatorOracle_OnlyAuthrorizedUsers() public {
        OracleData memory oracleData = createElementOracleData();

        Caller user = new Caller();
        AggregatorOracle aggregatorOracle = new AggregatorOracle();
            aggregatorOracle.allowCaller(
                aggregatorOracle.ANY_SIG(),
                address(factory)
            );

        // Deploy the oracle
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

    function test_deploy_DiscountRateAggregator_forEveryCompatibleValueProvider() public {
        for (
            uint256 oracleType = 0;
            oracleType < uint256(Factory.ValueProviderType.COUNT);
            oracleType++
        ) {
            // Set-up the mock providers
            AggregatorOracle mockAggregatorAddress = new AggregatorOracle();
            mockAggregatorAddress.allowCaller(mockAggregatorAddress.ANY_SIG(),address(factory));
            
            aggregatorOracleFactoryMock.givenQueryReturnResponse(
                abi.encodeWithSelector(
                    IFactoryAggregatorOracle.create.selector
                ),
                MockProvider.ReturnData({
                    success: true,
                    data: abi.encode(address(mockAggregatorAddress))
                }),
                false
            );

            CollybusDiscountRateRelayer discountRateRelayer = new CollybusDiscountRateRelayer(
                address(0xc011b005)
            );

            discountRateRelayer.allowCaller(discountRateRelayer.ANY_SIG(),address(factory));
            address aggregatorAddress = factory.deployDiscountRateAggregator(abi.encode(createDiscountRateAggregatorData(Factory.ValueProviderType(oracleType))),address(discountRateRelayer));

            assertTrue(
                aggregatorAddress != address(0),
                "Aggregator not deployed"
            );
        }
    }

    function test_deploy_DiscountRateAggregator_CheckExistanceOfOracles() public{
        // Set-up the mock providers
        AggregatorOracle mockAggregatorAddress = new AggregatorOracle();
        mockAggregatorAddress.allowCaller(mockAggregatorAddress.ANY_SIG(),address(factory));

        aggregatorOracleFactoryMock.givenQueryReturnResponse(
            abi.encodeWithSelector(
                IFactoryAggregatorOracle.create.selector
            ),
            MockProvider.ReturnData({
                success: true,
                data: abi.encode(address(mockAggregatorAddress))
            }),
            false
        );

        CollybusDiscountRateRelayer discountRateRelayer = new CollybusDiscountRateRelayer(
            address(0xc011b005)
        );

        discountRateRelayer.allowCaller(discountRateRelayer.ANY_SIG(),address(factory));

        DiscountRateAggregatorData
        memory aggregator = DiscountRateAggregatorData({
            tokenId: 1,
            oracleData: new bytes[](1),
            requiredValidValues: 1,
            minimumThresholdValue: 10**14
        });

        aggregator.oracleData[0] = abi.encode(createElementOracleData());

        address aggregatorAddress = factory.deployDiscountRateAggregator(abi.encode(aggregator),address(discountRateRelayer));

        assertEq(IAggregatorOracle(aggregatorAddress).oracleCount(),1,"Invalid Aggregator oracle count");
    }

    function test_deploy_DiscountRateAggregator_CheckValidValues() public{
        // Set-up the mock providers
        AggregatorOracle mockAggregatorAddress = new AggregatorOracle();
        mockAggregatorAddress.allowCaller(mockAggregatorAddress.ANY_SIG(),address(factory));

        aggregatorOracleFactoryMock.givenQueryReturnResponse(
            abi.encodeWithSelector(
                IFactoryAggregatorOracle.create.selector
            ),
            MockProvider.ReturnData({
                success: true,
                data: abi.encode(address(mockAggregatorAddress))
            }),
            false
        );

        CollybusDiscountRateRelayer discountRateRelayer = new CollybusDiscountRateRelayer(
            address(0xc011b005)
        );

        discountRateRelayer.allowCaller(discountRateRelayer.ANY_SIG(),address(factory));

        uint validValues = 1;
        DiscountRateAggregatorData
        memory aggregator = DiscountRateAggregatorData({
            tokenId: 1,
            oracleData: new bytes[](1),
            requiredValidValues: validValues,
            minimumThresholdValue: 10**14
        });

        aggregator.oracleData[0] = abi.encode(createElementOracleData());

        address aggregatorAddress = factory.deployDiscountRateAggregator(abi.encode(aggregator),address(discountRateRelayer));

        assertEq(AggregatorOracle(aggregatorAddress).requiredValidValues(),validValues,"Invalid required valid values");
    }

    function test_deploy_SpotPriceAggregator_forEveryCompatibleValueProvider() public {
        for (
            uint256 oracleType = 0;
            oracleType < uint256(Factory.ValueProviderType.COUNT);
            oracleType++
        ) {
            // Set-up the mock providers
            AggregatorOracle mockAggregatorAddress = new AggregatorOracle();
            mockAggregatorAddress.allowCaller(mockAggregatorAddress.ANY_SIG(),address(factory));
            
            aggregatorOracleFactoryMock.givenQueryReturnResponse(
                abi.encodeWithSelector(
                    IFactoryAggregatorOracle.create.selector
                ),
                MockProvider.ReturnData({
                    success: true,
                    data: abi.encode(address(mockAggregatorAddress))
                }),
                false
            );

            CollybusSpotPriceRelayer spotPriceRelayer = new CollybusSpotPriceRelayer(
                address(0xc011b005)
            );

            spotPriceRelayer.allowCaller(spotPriceRelayer.ANY_SIG(),address(factory));
            address aggregatorAddress = factory.deploySpotPriceAggregator(abi.encode(createSpotPriceAggregatorData(Factory.ValueProviderType(oracleType))),address(spotPriceRelayer));

            assertTrue(
                aggregatorAddress != address(0),
                "Aggregator not deployed"
            );
        }
    }

    function test_deploy_SpotPriceAggregator_CheckExistanceOfOracles() public{
        // Set-up the mock providers
        AggregatorOracle mockAggregatorAddress = new AggregatorOracle();
        mockAggregatorAddress.allowCaller(mockAggregatorAddress.ANY_SIG(),address(factory));

        aggregatorOracleFactoryMock.givenQueryReturnResponse(
            abi.encodeWithSelector(
                IFactoryAggregatorOracle.create.selector
            ),
            MockProvider.ReturnData({
                success: true,
                data: abi.encode(address(mockAggregatorAddress))
            }),
            false
        );

        CollybusSpotPriceRelayer spotPriceRelayer = new CollybusSpotPriceRelayer(
            address(0xc011b005)
        );

        spotPriceRelayer.allowCaller(spotPriceRelayer.ANY_SIG(),address(factory));

        SpotPriceAggregatorData
        memory aggregator = SpotPriceAggregatorData({
            tokenAddress: address(0x1234),
            oracleData: new bytes[](1),
            requiredValidValues: 1,
            minimumThresholdValue: 10**14
        });

        aggregator.oracleData[0] = abi.encode(createChainlinkOracleData());

        address aggregatorAddress = factory.deploySpotPriceAggregator(abi.encode(aggregator),address(spotPriceRelayer));

        assertEq(IAggregatorOracle(aggregatorAddress).oracleCount(),1,"Invalid Aggregator oracle count");
    }

    function test_deploy_SpotPriceAggregator_CheckValidValues() public{
        // Set-up the mock providers
        AggregatorOracle mockAggregatorAddress = new AggregatorOracle();
        mockAggregatorAddress.allowCaller(mockAggregatorAddress.ANY_SIG(),address(factory));

        aggregatorOracleFactoryMock.givenQueryReturnResponse(
            abi.encodeWithSelector(
                IFactoryAggregatorOracle.create.selector
            ),
            MockProvider.ReturnData({
                success: true,
                data: abi.encode(address(mockAggregatorAddress))
            }),
            false
        );

        CollybusSpotPriceRelayer spotPriceRelayer = new CollybusSpotPriceRelayer(
            address(0xc011b005)
        );

        spotPriceRelayer.allowCaller(spotPriceRelayer.ANY_SIG(),address(factory));

        uint validValues = 1;
        SpotPriceAggregatorData
        memory aggregator = SpotPriceAggregatorData({
            tokenAddress: address(0x1234),
            oracleData: new bytes[](1),
            requiredValidValues: validValues,
            minimumThresholdValue: 10**14
        });

        aggregator.oracleData[0] = abi.encode(createChainlinkOracleData());

        address aggregatorAddress = factory.deploySpotPriceAggregator(abi.encode(aggregator),address(spotPriceRelayer));

        assertEq(AggregatorOracle(aggregatorAddress).requiredValidValues(),validValues,"Invalid required valid values");
    }

    function test_deploy_collybusDiscountRateRelayer_createsContract() public {
        address collybus = address(0xC0111b005);
        CollybusDiscountRateRelayer mockRelayer = new CollybusDiscountRateRelayer(
            collybus
        );

        collybusDiscountRateRelayerFactoryMock.givenQueryReturnResponse(
            abi.encodeWithSelector(
                IFactoryCollybusDiscountRateRelayer.create.selector,
                collybus
            ),
            MockProvider.ReturnData({
                success: true,
                data: abi.encode(address(mockRelayer))
            }),
            false
        );

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

    function test_deploy_collybusSpotPriceRelayer_createsContract() public {
        address collybus = address(0xC01115107);
        CollybusSpotPriceRelayer mockRelayer = new CollybusSpotPriceRelayer(
            collybus
        );

        collybusSpotPriceRelayerFactoryMock.givenQueryReturnResponse(
            abi.encodeWithSelector(
                IFactoryCollybusSpotPriceRelayer.create.selector,
                collybus
            ),
            MockProvider.ReturnData({
                success: true,
                data: abi.encode(address(mockRelayer))
            }),
            false
        );
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

    function test_deploy_fullDiscountRateArchitecture() public {
        RelayerDeployData memory deployData = createDiscountRateDeployData();

        // Deploy the oracle architecture
        address discountRateRelayer = factory.deployDiscountRateArchitecture(
            abi.encode(deployData),
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

    function test_deploy_discountRate_addAggregator() public {
        RelayerDeployData memory deployData = createDiscountRateDeployData();

        // Deploy the oracle architecture
        address discountRateRelayer = factory.deployDiscountRateArchitecture(
            abi.encode(deployData),
            address(0x1234)
        );

        // Save the current aggregator count in the Relayer
        uint256 aggregatorCount = ICollybusDiscountRateRelayer(
            discountRateRelayer
        ).oracleCount();

        // Create the Aggregator data structure that will contain a Notional Oracle
        NotionalVPData memory notionalValueProvider = NotionalVPData({
            notionalViewAddress: 0x1344A36A1B56144C3Bc62E7757377D288fDE0369,
            currencyId: 2,
            lastImpliedRateDecimals: 9,
            maturityDate: 1671840000,
            settlementDate: 1648512000
        });

        OracleData memory notionalOracleData = OracleData({
            valueProviderData: abi.encode(notionalValueProvider),
            timeWindow: 200,
            maxValidTime: 600,
            alpha: 2 * 10**17,
            valueProviderType: uint8(Factory.ValueProviderType.Notional)
        });

        DiscountRateAggregatorData
            memory notionalAggregator = DiscountRateAggregatorData({
                tokenId: 3,
                oracleData: new bytes[](1),
                requiredValidValues: 1,
                minimumThresholdValue: 10**14
            });

        notionalAggregator.oracleData[0] = abi.encode(notionalOracleData);

        // Deploy the new aggregator
        address aggregatorAddress = factory.deployDiscountRateAggregator(
            abi.encode(notionalAggregator),
            discountRateRelayer
        );

        // The Relayer should contain an extra Aggregator/Oracle
        assertEq(
            aggregatorCount + 1,
            ICollybusDiscountRateRelayer(discountRateRelayer).oracleCount(),
            "Relayer should contain the new aggregator"
        );

        // The Relayer should contain the new aggregator
        assertTrue(
            ICollybusDiscountRateRelayer(discountRateRelayer).oracleExists(
                aggregatorAddress
            ),
            "Aggregator should exist"
        );
    }

    function test_deploy_discountRate_addOracle() public {
        RelayerDeployData memory deployData = createDiscountRateDeployData();

        // Deploy the oracle architecture
        address discountRateRelayer = factory.deployDiscountRateArchitecture(
            abi.encode(deployData),
            address(0x1234)
        );

        // Get the address of the first aggregator
        address firstAggregatorAddress = ICollybusDiscountRateRelayer(
            discountRateRelayer
        ).oracleAt(0);

        NotionalVPData memory notionalValueProvider = NotionalVPData({
            notionalViewAddress: 0x1344A36A1B56144C3Bc62E7757377D288fDE0369,
            currencyId: 2,
            lastImpliedRateDecimals: 9,
            maturityDate: 1671840000,
            settlementDate: 1648512000
        });

        OracleData memory notionalOracleData = OracleData({
            valueProviderData: abi.encode(notionalValueProvider),
            timeWindow: 200,
            maxValidTime: 600,
            alpha: 2 * 10**17,
            valueProviderType: uint8(Factory.ValueProviderType.Notional)
        });

        // Cache the number of oracles in the aggregator
        uint256 oracleCount = IAggregatorOracle(firstAggregatorAddress)
            .oracleCount();

        // Create and add the oracle to the aggregator
        address oracleAddress = factory.deployAggregatorOracle(
            abi.encode(notionalOracleData),
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

    function test_deploy_fullSpotPriceArchitecture() public {
        RelayerDeployData memory deployData = createSpotPriceDeployData();

        // Deploy the oracle architecture
        address spotPriceRelayer = factory.deploySpotPriceArchitecture(
            abi.encode(deployData),
            address(0x1234)
        );

        // Check the creation of the discount rate relayer
        assertTrue(
            spotPriceRelayer != address(0),
            "CollybusSpotPriceRelayer should be deployed"
        );

        assertEq(
            ICollybusSpotPriceRelayer(spotPriceRelayer).oracleCount(),
            deployData.aggregatorData.length,
            "CollybusSpotPriceRelayer invalid aggregator count"
        );
    }

    function test_deploy_spotPrice_addAggregator() public {
        RelayerDeployData memory deployData = createSpotPriceDeployData();

        // Deploy the oracle architecture
        address spotPriceRelayer = factory.deploySpotPriceArchitecture(
            abi.encode(deployData),
            address(0x1234)
        );

        // Save the current aggregator count in the Relayer
        uint256 aggregatorCount = ICollybusSpotPriceRelayer(spotPriceRelayer)
            .oracleCount();

        // Define the needed data for the new aggregator
        ChainlinkVPData memory chainlinkValueProvider = createChainlinkVPData();

        OracleData memory chainlinkOracleData = OracleData({
            valueProviderData: abi.encode(chainlinkValueProvider),
            timeWindow: 200,
            maxValidTime: 600,
            alpha: 2 * 10**17,
            valueProviderType: uint8(Factory.ValueProviderType.Chainlink)
        });

        // The first aggregator is at address 0x1, make the second one use a different address
        SpotPriceAggregatorData
            memory chainlinkAggregator = SpotPriceAggregatorData({
                tokenAddress: address(0x2),
                oracleData: new bytes[](1),
                requiredValidValues: 1,
                minimumThresholdValue: 10**14
            });

        chainlinkAggregator.oracleData[0] = abi.encode(chainlinkOracleData);

        // Deploy the new aggregator
        address aggregatorAddress = factory.deploySpotPriceAggregator(
            abi.encode(chainlinkAggregator),
            spotPriceRelayer
        );

        // The Relayer should contain an extra Aggregator/Oracle
        assertEq(
            aggregatorCount + 1,
            ICollybusSpotPriceRelayer(spotPriceRelayer).oracleCount(),
            "Relayer should contain the new aggregator"
        );

        // The Relayer should contain the new aggregator
        assertTrue(
            ICollybusSpotPriceRelayer(spotPriceRelayer).oracleExists(
                aggregatorAddress
            ),
            "Aggregator should exist"
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

        MockProvider poolToken = new MockProvider();
        poolToken.givenQueryReturnResponse(
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
            poolToken: address(poolToken),
            underlier: address(underlierMock),
            ePTokenBond: address(ePTokenBondMock),
            timeScale: 2426396518,
            maturity: 1651275535
        });

        return elementValueProvider;
    }

    function createNotionalVPData() public returns (NotionalVPData memory) {
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
        YieldVPData memory yieldValueProviderData = YieldVPData({
            poolAddress: address(0x123),
            maturity: 1648177200,
            timeScale: 3168808781
        });

        return yieldValueProviderData;
    }

    function createElementOracleData() internal returns (OracleData memory) {
        return
            OracleData({
                valueProviderData: abi.encode(
                    ElementVPData(
                        0,
                        address(0),
                        address(0),
                        address(0),
                        address(0),
                        0,
                        0
                    )
                ),
                timeWindow: 0,
                maxValidTime: 0,
                alpha: 0,
                valueProviderType: uint8(Factory.ValueProviderType.Element)
            });
    }

    function createNotionalOracleData() internal returns (OracleData memory) {
        return
            OracleData({
                valueProviderData: abi.encode(
                    NotionalVPData(address(0), 0, 0, 0, 0)
                ),
                timeWindow: 0,
                maxValidTime: 0,
                alpha: 0,
                valueProviderType: uint8(Factory.ValueProviderType.Notional)
            });
    }

    function createYieldOracleData() internal returns (OracleData memory) {
        return
            OracleData({
                valueProviderData: abi.encode(YieldVPData(address(0), 0, 0)),
                timeWindow: 0,
                maxValidTime: 0,
                alpha: 0,
                valueProviderType: uint8(Factory.ValueProviderType.Yield)
            });
    }

    function createChainlinkOracleData() internal returns (OracleData memory) {
        return
            OracleData({
                valueProviderData: abi.encode(ChainlinkVPData(address(0))),
                timeWindow: 0,
                maxValidTime: 0,
                alpha: 0,
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

    function createDiscountRateAggregatorData(Factory.ValueProviderType valueType) internal returns (DiscountRateAggregatorData memory)
    {
        DiscountRateAggregatorData
        memory aggregator = DiscountRateAggregatorData({
            tokenId: 1,
            oracleData: new bytes[](1),
            requiredValidValues: 1,
            minimumThresholdValue: 10**14
        });

        if (valueType == Factory.ValueProviderType.Element) {
            aggregator.oracleData[0] = abi.encode(createElementOracleData());
        } else if (valueType == Factory.ValueProviderType.Notional) {
            aggregator.oracleData[0] = abi.encode(createNotionalOracleData());
        } else if (valueType == Factory.ValueProviderType.Yield){
            aggregator.oracleData[0] = abi.encode(createYieldOracleData());
        } else if (valueType == Factory.ValueProviderType.Chainlink){
            aggregator.oracleData[0] = abi.encode(createChainlinkOracleData());
        } else {
            revert FactoryTest__invalidDiscountRateAggregatorType(uint(valueType));
        }

        return aggregator;
    }

    function createSpotPriceAggregatorData(Factory.ValueProviderType valueType) internal returns (SpotPriceAggregatorData memory)
    {
        SpotPriceAggregatorData
        memory aggregator = SpotPriceAggregatorData({
            tokenAddress: address(0x1234),
            oracleData: new bytes[](1),
            requiredValidValues: 1,
            minimumThresholdValue: 10**14
        });

        if (valueType == Factory.ValueProviderType.Element) {
            aggregator.oracleData[0] = abi.encode(createElementOracleData());
        } else if (valueType == Factory.ValueProviderType.Notional) {
            aggregator.oracleData[0] = abi.encode(createNotionalOracleData());
        } else if (valueType == Factory.ValueProviderType.Yield){
            aggregator.oracleData[0] = abi.encode(createYieldOracleData());
        } else if (valueType == Factory.ValueProviderType.Chainlink){
            aggregator.oracleData[0] = abi.encode(createChainlinkOracleData());
        } else {
            revert FactoryTest__invalidDiscountRateAggregatorType(uint(valueType));
        }

        return aggregator;
    }

    function createDiscountRateDeployData()
        internal
        returns (RelayerDeployData memory)
    {
        OracleData memory notionalOracleData = createNotionalOracleData();

        DiscountRateAggregatorData
            memory notionalAggregator = DiscountRateAggregatorData({
                tokenId: 1,
                oracleData: new bytes[](1),
                requiredValidValues: 1,
                minimumThresholdValue: 10**14
            });

        notionalAggregator.oracleData[0] = abi.encode(notionalOracleData);

        ElementVPData memory elementValueProvider = createElementVPData();

        OracleData memory elementOracleData = OracleData({
            valueProviderData: abi.encode(elementValueProvider),
            timeWindow: 200,
            maxValidTime: 600,
            alpha: 2 * 10**17,
            valueProviderType: uint8(Factory.ValueProviderType.Element)
        });

        DiscountRateAggregatorData
            memory elementAggregator = DiscountRateAggregatorData({
                tokenId: 2,
                oracleData: new bytes[](1),
                requiredValidValues: 1,
                minimumThresholdValue: 10**14
            });

        elementAggregator.oracleData[0] = abi.encode(elementOracleData);

        RelayerDeployData memory deployData;
        deployData.aggregatorData = new bytes[](2);
        deployData.aggregatorData[0] = abi.encode(elementAggregator);
        deployData.aggregatorData[1] = abi.encode(notionalAggregator);

        return deployData;
    }

    function createSpotPriceDeployData()
        internal
        returns (RelayerDeployData memory)
    {
        ChainlinkVPData memory chainlinkValueProvider = createChainlinkVPData();

        OracleData memory chainlinkOracleData = OracleData({
            valueProviderData: abi.encode(chainlinkValueProvider),
            timeWindow: 200,
            maxValidTime: 600,
            alpha: 2 * 10**17,
            valueProviderType: uint8(Factory.ValueProviderType.Chainlink)
        });

        SpotPriceAggregatorData
            memory chainlinkAggregator = SpotPriceAggregatorData({
                tokenAddress: address(0x1),
                oracleData: new bytes[](1),
                requiredValidValues: 1,
                minimumThresholdValue: 10**14
            });

        chainlinkAggregator.oracleData[0] = abi.encode(chainlinkOracleData);

        RelayerDeployData memory deployData;
        deployData.aggregatorData = new bytes[](1);
        deployData.aggregatorData[0] = abi.encode(chainlinkAggregator);
        return deployData;
    }
}