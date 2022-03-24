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

// Contract Deployers and dependencies
import {ElementFiValueProviderFactory} from "./ElementFiValueProviderFactory.sol";
import {NotionalFinanceValueProviderFactory} from "./NotionalFinanceValueProviderFactory.sol";
import {YieldValueProviderFactory} from "./YieldValueProviderFactory.sol";
import {ChainlinkValueProviderFactory} from "./ChainlinkValueProviderFactory.sol";
import {RelayerFactory} from "./RelayerFactory.sol";
import {ChainlinkMockProvider} from "../deploy/ChainlinkMockProvider.sol";
import {IYieldPool} from "../oracle_implementations/discount_rate/Yield/IYieldPool.sol";
import {IChainlinkAggregatorV3Interface} from "../oracle_implementations/spot_price/Chainlink/ChainlinkAggregatorV3Interface.sol";

// Relayers
import {IRelayer} from "../relayer/IRelayer.sol";
import {Relayer} from "../relayer/Relayer.sol";

contract FactoryTest is DSTest {
    error FactoryTest__invalidDiscountRateAggregatorType(uint256 valueType);
    error FactoryTest__invalidSpotPriceAggregatorType(uint256 valueType);

    Factory internal factory;

    ElementFiValueProviderFactory internal elementFiValueProviderFactoryMock;
    NotionalFinanceValueProviderFactory
        internal notionalValueProviderFactoryMock;
    YieldValueProviderFactory internal yieldValueProviderFactoryMock;
    ChainlinkValueProviderFactory internal chainlinkValueProviderFactoryMock;
    RelayerFactory internal relayerFactoryMock;

    function setUp() public {
        // Create all the contract factories needed by the main factory
        elementFiValueProviderFactoryMock = new ElementFiValueProviderFactory();
        notionalValueProviderFactoryMock = new NotionalFinanceValueProviderFactory();
        yieldValueProviderFactoryMock = new YieldValueProviderFactory();
        chainlinkValueProviderFactoryMock = new ChainlinkValueProviderFactory();
        relayerFactoryMock = new RelayerFactory();

        factory = new Factory(
            address(elementFiValueProviderFactoryMock),
            address(notionalValueProviderFactoryMock),
            address(yieldValueProviderFactoryMock),
            address(chainlinkValueProviderFactoryMock),
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
            factory.relayerFactory(),
            address(relayerFactoryMock),
            "Invalid relayerFactory"
        );
    }

    function test_setPermission_callsAllowCaller_withCorrectArguments(
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

    function test_authorizedUser_canSetPermission(bytes32 sig_, address who_)
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

    function test_removePermission_callsBlockCaller_withCorrectArguments(
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

    function test_unauthorizedUser_cannotRemovePermission(
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

    function test_authorizedUser_canRemovePermission(bytes32 sig_, address who_)
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

    function test_deployElementFiValueProvider() public {
        // Create the oracle data structure
        ElementVPData memory elementValueProvider = createElementVPData();
        OracleData memory elementDataOracle = OracleData({
            valueProviderData: abi.encode(elementValueProvider),
            timeWindow: 100,
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

    function test_deployElementFiValueProvider_onlyAuthorizedUsers() public {
        // Create the oracle data structure
        ElementVPData memory elementValueProvider = createElementVPData();
        OracleData memory elementDataOracle = OracleData({
            valueProviderData: abi.encode(elementValueProvider),
            timeWindow: 100,
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

    function test_deployNotionalFinanceValueProvider() public {
        // Create the oracle data structure
        NotionalVPData memory notionalValueProvider = createNotionalVPData();
        OracleData memory notionalDataOracle = OracleData({
            valueProviderData: abi.encode(notionalValueProvider),
            timeWindow: 100,
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

    function test_deployNotionalFinanceValueProvider_onlyAuthorizedUsers()
        public
    {
        // Create the oracle data structure
        NotionalVPData memory notionalValueProvider = createNotionalVPData();
        OracleData memory notionalDataOracle = OracleData({
            valueProviderData: abi.encode(notionalValueProvider),
            timeWindow: 100,
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

    function test_deployYieldValueProvider() public {
        // Create the oracle data structure
        YieldVPData memory yieldValueProvider = createYieldVPData();
        OracleData memory yieldDataOracle = OracleData({
            valueProviderData: abi.encode(yieldValueProvider),
            timeWindow: 100,
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

    function test_deployYieldValueProvider_onlyAuthorizedUsers() public {
        // Create the oracle data structure
        YieldVPData memory yieldValueProvider = createYieldVPData();
        OracleData memory yieldDataOracle = OracleData({
            valueProviderData: abi.encode(yieldValueProvider),
            timeWindow: 100,
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

    function test_deployChainlinkValueProvider() public {
        // Create the oracle data structure
        ChainlinkVPData memory chainlinkValueProvider = createChainlinkVPData();
        OracleData memory chainlinkDataOracle = OracleData({
            valueProviderData: abi.encode(chainlinkValueProvider),
            timeWindow: 100,
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

    function test_deployChainlinkValueProvider_onlyAuthorizedUsers() public {
        // Create the oracle data structure
        ChainlinkVPData memory chainlinkValueProvider = createChainlinkVPData();
        OracleData memory chainlinkDataOracle = OracleData({
            valueProviderData: abi.encode(chainlinkValueProvider),
            timeWindow: 100,
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

    function test_deployOracle_forEveryValueProviderType() public {
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
            // Deploy and add the oracle to the aggregator oracle
            address oracleAddress = factory.deployOracle(
                oracleData[oracleType]
            );

            // Check that the oracle was created
            assertTrue(oracleAddress != address(0));
        }
    }

    function test_deployOracle_onlyAuthorizedUsers() public {
        OracleData memory oracleData = createElementOracleData();
        Caller user = new Caller();
        // Call deployOracle
        (bool ok, ) = user.externalCall(
            address(factory),
            abi.encodeWithSelector(
                factory.deployOracle.selector,
                abi.encode(oracleData)
            )
        );

        assertTrue(
            ok == false,
            "Only authorized users should be able to call deployOracle"
        );
    }

    function test_deployRelayer_createsContract() public {
        address collybus = address(0xC0111b005);
        RelayerData memory relayerData;
        relayerData.encodedTokenId = bytes32(uint256(1));
        relayerData.minimumPercentageDeltaValue = 1;
        relayerData.oracleData = createElementOracleData();

        for (
            uint256 relayerType = 0;
            relayerType < uint256(IRelayer.RelayerType.COUNT);
            relayerType++
        ) {
            address relayer = factory.deployRelayer(
                collybus,
                IRelayer.RelayerType(relayerType),
                relayerData
            );

            // Make sure the Relayer was deployed
            assertTrue(relayer != address(0), "Relayer should be deployed");
        }
    }

    function test_deployRelayer_onlyAuthorizedUsers() public {
        Caller user = new Caller();
        address collybus = address(0xC0111b005);

        // Call deployRelayer
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

    function testFail_deployRelayer_failsWithInvalidCollybus() public {
        address collybus = address(0);
        RelayerData memory relayerData;
        relayerData.encodedTokenId = bytes32(uint256(1));
        relayerData.minimumPercentageDeltaValue = 1;
        relayerData.oracleData = createElementOracleData();

        factory.deployRelayer(
            collybus,
            IRelayer.RelayerType.DiscountRate,
            relayerData
        );
    }

    function test_deployStaticRelayer_createsContract() public {
        address collybus = address(0xC0111b005);
        bytes32 encodedTokenId = bytes32(uint256(1));
        uint256 value = 1;

        for (
            uint256 relayerType = 0;
            relayerType < uint256(IRelayer.RelayerType.COUNT);
            relayerType++
        ) {
            address staticRelayer = factory.deployStaticRelayer(
                collybus,
                IRelayer.RelayerType(relayerType),
                encodedTokenId,
                value
            );

            // Make sure the StaticRelayer was deployed
            assertTrue(
                staticRelayer != address(0),
                "StaticRelayer should be deployed"
            );
        }
    }

    function test_deployStaticRelayer_onlyAuthorizedUsers() public {
        Caller user = new Caller();
        address collybus = address(0xC0111b005);

        // Call deployStaticRelayer
        (bool ok, ) = user.externalCall(
            address(factory),
            abi.encodeWithSelector(
                factory.deployStaticRelayer.selector,
                collybus,
                IRelayer.RelayerType.DiscountRate,
                bytes32(uint256(1)),
                1
            )
        );

        assertTrue(
            ok == false,
            "Only authorized users should be able to deploy StaticRelayers"
        );
    }

    function testFail_deployStaticRelayer_failsWithInvalidCollybus() public {
        address collybus = address(0);
        bytes32 encodedTokenId = bytes32(uint256(1));
        uint256 value = 1;

        factory.deployStaticRelayer(
            collybus,
            IRelayer.RelayerType.DiscountRate,
            encodedTokenId,
            value
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
                valueProviderType: uint8(Factory.ValueProviderType.Notional)
            });
    }

    function createYieldOracleData() internal returns (OracleData memory) {
        return
            OracleData({
                valueProviderData: abi.encode(createYieldVPData()),
                timeWindow: 0,
                valueProviderType: uint8(Factory.ValueProviderType.Yield)
            });
    }

    function createChainlinkOracleData() internal returns (OracleData memory) {
        return
            OracleData({
                valueProviderData: abi.encode(createChainlinkVPData()),
                timeWindow: 0,
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
}
