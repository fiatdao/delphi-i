// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import {IOracle} from "src/oracle/IOracle.sol";
import {IAggregatorOracle} from "src/aggregator/IAggregatorOracle.sol";

// Contract Deployers
import {IFactoryElementFiValueProvider} from "src/factory/FactoryElementFiValueProvider.sol";
import {IFactoryNotionalFinanceValueProvider} from "src/factory/FactoryNotionalFinanceValueProvider.sol";
import {IFactoryYieldValueProvider} from "src/factory/FactoryYieldValueProvider.sol";
import {IFactoryChainlinkValueProvider} from "src/factory/FactoryChainlinkValueProvider.sol";
import {IFactoryAggregatorOracle} from "src/factory/FactoryAggregatorOracle.sol";
import {IFactoryCollybusSpotPriceRelayer} from "src/factory/FactoryCollybusSpotPriceRelayer.sol";
import {IFactoryCollybusDiscountRateRelayer} from "src/factory/FactoryCollybusDiscountRateRelayer.sol";

// Relayers
import {ICollybusDiscountRateRelayer} from "src/relayer/CollybusDiscountRate/ICollybusDiscountRateRelayer.sol";
import {ICollybusSpotPriceRelayer} from "src/relayer/CollybusSpotPrice/ICollybusSpotPriceRelayer.sol";

import {Guarded} from "src/guarded/Guarded.sol";

/// @notice Data structure that wraps data needed to deploy an Element Value Provider contract
struct ElementVPData {
    bytes32 poolId;
    address balancerVault;
    address poolToken;
    address underlier;
    address ePTokenBond;
    int256 timeScale;
    uint256 maturity;
}

/// @notice Data structure that wraps data needed to deploy an Notional Value Provider contract
struct NotionalVPData {
    address notionalViewAddress;
    uint16 currencyId;
    uint256 lastImpliedRateDecimals;
    uint256 maturityDate;
    uint256 settlementDate;
}

/// @notice Data structure that wraps data needed to deploy a Chainlink spot price value provider
struct ChainlinkVPData {
    address chainlinkAggregatorAddress;
}

/// @notice Data structure that wraps data needed to deploy a Yield value provider
struct YieldVPData {
    address poolAddress;
    uint256 maturity;
    int256 timeScale;
}

/// @notice Data structure that wraps needed data to deploy an Oracle contract
/// @dev The value provider data field is a abi.encoded struct based on the given providerType
/// @dev The Factory will revert if the providerType is not found
struct OracleData {
    bytes valueProviderData;
    uint8 valueProviderType;
    uint256 timeWindow;
    uint256 maxValidTime;
    int256 alpha;
}

/// @notice Data structure that wraps needed data to deploy an Oracle Aggregator contract
/// @dev The oracleData array field contains abi.encoded OracleData structures
/// @dev Factory will revert if the requiredValidValues is bigger than the oracleData item count
struct DiscountRateAggregatorData {
    uint256 tokenId;
    bytes[] oracleData;
    uint256 requiredValidValues;
    uint256 minimumThresholdValue;
}

/// @notice Data structure that wraps needed data to deploy an Oracle Aggregator contract
/// @dev The oracleData field contains a abi.encoded OracleData structure
///      We only have one oracle per aggregator as we trust chainlink as the single source or truth
/// @dev Factory will revert if the requiredValidValues is bigger than the oracleData item count
struct SpotPriceAggregatorData {
    address tokenAddress;
    bytes[] oracleData;
    uint256 requiredValidValues;
    uint256 minimumThresholdValue;
}

/// @notice Data structure that wraps needed data to deploy a full Relayer architecture
/// @dev The aggregatorData field contains abi.encoded DiscountRateAggregatorData or SpotPriceAggregatorData structures
/// @dev Factory will revert if the aggregators do not contain unique tokenId's
struct RelayerDeployData {
    bytes[] aggregatorData;
}

contract Factory is Guarded {
    event RelayerDeployed(address relayerAddress, uint256 relayerType);
    event AggregatorDeployed(address aggregatorAddress, uint256 relayerType);
    event OracleDeployed(address oracleAddress);

    // @notice Emitted when the collybus address is address(0)
    error Factory__deployCollybusDiscountRateRelayer_invalidCollybusAddress();

    // @notice Emitted when the collybus address is address(0)
    error Factory__deployCollybusSpotPriceRelayer_invalidCollybusAddress();

    // @notice Emitted if no value provider is found for given providerType
    error Factory__deployOracle_invalidValueProviderType(uint8);

    // Supported value provider oracle types
    enum ValueProviderType {
        Element,
        Notional,
        Yield,
        Chainlink,
        COUNT
    }

    enum RelayerType {
        DiscountRate,
        SpotPrice
    }

    address public immutable elementFiValueProviderFactory;
    address public immutable notionalValueProviderFactory;
    address public immutable yieldValueProviderFactory;
    address public immutable chainlinkValueProviderFactory;
    address public immutable aggregatorOracleFactory;
    address public immutable collybusDiscountRateRelayerFactory;
    address public immutable collybusSpotPriceRelayerFactory;

    constructor(
        address elementFiValueProviderFactory_,
        address notionalValueProviderFactory_,
        address yieldValueProviderFactory_,
        address chainlinkValueProviderFactory_,
        address aggregatorOracleFactory_,
        address collybusDiscountRateRelayerFactory_,
        address collybusSpotPriceRelayerFactory_
    ) {
        elementFiValueProviderFactory = elementFiValueProviderFactory_;
        notionalValueProviderFactory = notionalValueProviderFactory_;
        yieldValueProviderFactory = yieldValueProviderFactory_;
        chainlinkValueProviderFactory = chainlinkValueProviderFactory_;
        aggregatorOracleFactory = aggregatorOracleFactory_;
        collybusDiscountRateRelayerFactory = collybusDiscountRateRelayerFactory_;
        collybusSpotPriceRelayerFactory = collybusSpotPriceRelayerFactory_;
    }

    /// @notice Deploys an Element Fi Value Provider
    /// @dev For more information about the params please check the Value Provider Contract
    /// todo: add GitHub URL contract
    /// @return Returns the address of the new value provider
    function deployElementFiValueProvider(
        // Oracle params
        OracleData memory oracleParams_
    ) public checkCaller returns (address) {
        ElementVPData memory elementParams = abi.decode(
            oracleParams_.valueProviderData,
            (ElementVPData)
        );

        address elementFiValueProviderAddress = IFactoryElementFiValueProvider(
            elementFiValueProviderFactory
        ).create(
                oracleParams_.timeWindow,
                oracleParams_.maxValidTime,
                oracleParams_.alpha,
                elementParams.poolId,
                elementParams.balancerVault,
                elementParams.poolToken,
                elementParams.underlier,
                elementParams.ePTokenBond,
                elementParams.timeScale,
                elementParams.maturity
            );

        return elementFiValueProviderAddress;
    }

    /// @notice Deploys a Notional Finance Value Provider
    /// @dev For more information about the params please check the Value Provider Contract
    /// todo: add GitHub URL contract
    /// @return Returns the address of the new value provider
    function deployNotionalFinanceValueProvider(
        // Oracle params
        OracleData memory oracleParams_
    ) public checkCaller returns (address) {
        NotionalVPData memory notionalParams = abi.decode(
            oracleParams_.valueProviderData,
            (NotionalVPData)
        );

        address notionalFinanceValueProviderAddress = IFactoryNotionalFinanceValueProvider(
                notionalValueProviderFactory
            ).create(
                    oracleParams_.timeWindow,
                    oracleParams_.maxValidTime,
                    oracleParams_.alpha,
                    notionalParams.notionalViewAddress,
                    notionalParams.currencyId,
                    notionalParams.lastImpliedRateDecimals,
                    notionalParams.maturityDate,
                    notionalParams.settlementDate
                );

        return notionalFinanceValueProviderAddress;
    }

    /// @notice Deploys an Yield Value Provider
    /// @dev For more information about the params please check the Value Provider Contract
    /// todo: add the master github path to contract
    /// @return Returns the address of the new value provider
    function deployYieldValueProvider(
        // Oracle params
        OracleData memory oracleParams
    ) public checkCaller returns (address) {
        YieldVPData memory yieldParams = abi.decode(
            oracleParams.valueProviderData,
            (YieldVPData)
        );

        address yieldValueProviderAddress = IFactoryYieldValueProvider(
            yieldValueProviderFactory
        ).create(
                oracleParams.timeWindow,
                oracleParams.maxValidTime,
                oracleParams.alpha,
                yieldParams.poolAddress,
                yieldParams.maturity,
                yieldParams.timeScale
            );

        return yieldValueProviderAddress;
    }

    /// @notice Deploys an Chainlink Value Provider
    /// @dev For more information about the params please check the Value Provider Contract
    /// todo: add the master github path to contract
    /// @return Returns the address of the new value provider
    function deployChainlinkValueProvider(
        // Oracle params
        OracleData memory oracleParams_
    ) public checkCaller returns (address) {
        ChainlinkVPData memory chainlinkParams = abi.decode(
            oracleParams_.valueProviderData,
            (ChainlinkVPData)
        );

        address chainlinkValueProviderAddress = IFactoryChainlinkValueProvider(
            chainlinkValueProviderFactory
        ).create(
                oracleParams_.timeWindow,
                oracleParams_.maxValidTime,
                oracleParams_.alpha,
                chainlinkParams.chainlinkAggregatorAddress
            );

        return chainlinkValueProviderAddress;
    }

    /// @notice Deploys a new Oracle and adds it to an Aggregator
    /// @param oracleDataEncoded_ ABI encoded Oracle data structure
    /// @param aggregatorAddress_ The aggregator address that will contain the created Oracle
    /// @dev Reverts if the encoded struct can not be decoded
    /// @return Returns the address of the new Oracle
    function deployAggregatorOracle(
        bytes memory oracleDataEncoded_,
        address aggregatorAddress_
    ) public checkCaller returns (address) {
        // Decode oracle data
        OracleData memory oracleData = abi.decode(
            oracleDataEncoded_,
            (OracleData)
        );

        address oracleAddress;

        // Create the value provider based on valueProviderType
        // Revert if no match match is found
        if (oracleData.valueProviderType == uint8(ValueProviderType.Element)) {
            // Create the value provider
            oracleAddress = deployElementFiValueProvider(oracleData);
        } else if (
            oracleData.valueProviderType == uint8(ValueProviderType.Notional)
        ) {
            // Create the value provider
            oracleAddress = deployNotionalFinanceValueProvider(oracleData);
        } else if (
            oracleData.valueProviderType == uint8(ValueProviderType.Chainlink)
        ) {
            // Create the value provider
            oracleAddress = deployChainlinkValueProvider(oracleData);
        } else if (
            oracleData.valueProviderType == uint8(ValueProviderType.Yield)
        ) {
            // Create the value provider
            oracleAddress = deployYieldValueProvider(oracleData);
        } else {
            // Revert if the value provider type is not supported
            revert Factory__deployOracle_invalidValueProviderType(
                oracleData.valueProviderType
            );
        }

        // Add the oracle to the Aggregator Oracle
        IAggregatorOracle(aggregatorAddress_).oracleAdd(oracleAddress);
        emit OracleDeployed(oracleAddress);

        return oracleAddress;
    }

    /// @notice Deploys a new Aggregator and adds it to a Relayer
    /// @param aggregatorDataEncoded_ ABI encoded Aggregator data structure
    /// @param discountRateRelayerAddress_ The address of the discount rate relayer where we will add the aggregator
    /// @dev Reverts if the encoded struct can not be decoded
    /// @return Returns the address of the new Aggregator
    function deployDiscountRateAggregator(
        bytes memory aggregatorDataEncoded_,
        address discountRateRelayerAddress_
    ) public checkCaller returns (address) {
        // Create aggregator contract
        address aggregatorOracleAddress = IFactoryAggregatorOracle(
            aggregatorOracleFactory
        ).create();

        // Decode aggregator structure
        DiscountRateAggregatorData memory aggData = abi.decode(
            aggregatorDataEncoded_,
            (DiscountRateAggregatorData)
        );

        // Iterate and deploy each oracle
        uint256 oracleCount = aggData.oracleData.length;
        for (
            uint256 oracleIndex = 0;
            oracleIndex < oracleCount;
            oracleIndex++
        ) {
            // TODO: We can use the oracles returned address to emit events
            // Each oracle is also added to the aggregator
            deployAggregatorOracle(
                aggData.oracleData[oracleIndex],
                aggregatorOracleAddress
            );
        }

        // Set the minimum required valid values for the aggregator
        // Reverts if the requiredValidValues is greater than the oracleCount
        IAggregatorOracle(aggregatorOracleAddress).setParam(
            "requiredValidValues",
            aggData.requiredValidValues
        );

        // Add the aggregator to the relayer
        // Reverts if the tokenId is not unique
        // Reverts if the Aggregator is already used
        ICollybusDiscountRateRelayer(discountRateRelayerAddress_).oracleAdd(
            aggregatorOracleAddress,
            aggData.tokenId,
            aggData.minimumThresholdValue
        );

        emit AggregatorDeployed(
            aggregatorOracleAddress,
            uint256(RelayerType.DiscountRate)
        );
        return aggregatorOracleAddress;
    }

    /// @notice Deploys a new Aggregator and adds it to a Relayer
    /// @param aggregatorDataEncoded_ ABI encoded Oracle data structure
    /// @param spotPriceRelayerAddress_ The address of the spot price relayer where we will add the aggregator
    /// @dev Reverts if the encoded struct can not be decoded
    /// @return Returns the address of the new Aggregator
    function deploySpotPriceAggregator(
        bytes memory aggregatorDataEncoded_,
        address spotPriceRelayerAddress_
    ) public checkCaller returns (address) {
        // Create aggregator contract
        address aggregatorOracleAddress = IFactoryAggregatorOracle(
            aggregatorOracleFactory
        ).create();

        // Decode aggregator structure
        SpotPriceAggregatorData memory aggData = abi.decode(
            aggregatorDataEncoded_,
            (SpotPriceAggregatorData)
        );

        // Iterate and deploy each oracle
        uint256 oracleCount = aggData.oracleData.length;
        for (
            uint256 oracleIndex = 0;
            oracleIndex < oracleCount;
            oracleIndex++
        ) {
            // TODO: We can use the oracles returned address to emit events
            // Each oracle is also added to the aggregator
            deployAggregatorOracle(
                aggData.oracleData[oracleIndex],
                aggregatorOracleAddress
            );
        }

        // Set the minimum required valid values for the aggregator
        // Reverts if the requiredValidValues is greater than the oracleCount
        IAggregatorOracle(aggregatorOracleAddress).setParam(
            "requiredValidValues",
            aggData.requiredValidValues
        );

        // Add the aggregator to the relayer
        // Reverts if the tokenAddress is not unique
        // Revert if the Aggregator is already used
        ICollybusSpotPriceRelayer(spotPriceRelayerAddress_).oracleAdd(
            aggregatorOracleAddress,
            aggData.tokenAddress,
            aggData.minimumThresholdValue
        );

        emit AggregatorDeployed(
            aggregatorOracleAddress,
            uint256(RelayerType.SpotPrice)
        );
        return aggregatorOracleAddress;
    }

    /// @notice Deploys a new Discount Rate Relayer
    /// @param collybus_ Address of Collybus
    /// @dev Reverts if Collybus is not set
    /// @return Returns the address of the Relayer
    function deployCollybusDiscountRateRelayer(address collybus_)
        public
        checkCaller
        returns (address)
    {
        // Collybus address is needed in order to deploy the Discount Rate Relayer
        if (collybus_ == address(0)) {
            revert Factory__deployCollybusDiscountRateRelayer_invalidCollybusAddress();
        }

        address discountRateRelayerAddress = IFactoryCollybusDiscountRateRelayer(
                collybusDiscountRateRelayerFactory
            ).create(collybus_);

        emit RelayerDeployed(
            discountRateRelayerAddress,
            uint256(RelayerType.DiscountRate)
        );
        return discountRateRelayerAddress;
    }

    /// @notice Deploys a new Spot Price Relayer
    /// @param collybus_ Address of Collybus
    /// @dev Reverts if Collybus is not set
    /// @return Returns the address of the Relayer
    function deployCollybusSpotPriceRelayer(address collybus_)
        public
        checkCaller
        returns (address)
    {
        // The Collybus address is needed in order to deploy the Spot Price Rate Relayer
        if (collybus_ == address(0)) {
            revert Factory__deployCollybusSpotPriceRelayer_invalidCollybusAddress();
        }

        address spotPriceRelayerAddress = IFactoryCollybusSpotPriceRelayer(
            collybusSpotPriceRelayerFactory
        ).create(collybus_);

        emit RelayerDeployed(
            spotPriceRelayerAddress,
            uint256(RelayerType.SpotPrice)
        );
        return spotPriceRelayerAddress;
    }

    /// @notice Deploys a full Discount Rate Relayer architecture, can contain Aggregator Oracles and Oracles
    /// @param discountRateRelayerDataEncoded_ ABI encoded RelayerDeployData struct
    /// @param collybus_ Collybus address
    /// @dev Reverts on dependencies checks and conditions
    /// @return Returns the Discount Rate Relayer
    function deployDiscountRateArchitecture(
        bytes memory discountRateRelayerDataEncoded_,
        address collybus_
    ) public checkCaller returns (address) {
        RelayerDeployData memory discountRateRelayerData = abi.decode(
            discountRateRelayerDataEncoded_,
            (RelayerDeployData)
        );
        // Create the relayer and cache the address
        address discountRateRelayerAddress = deployCollybusDiscountRateRelayer(
            collybus_
        );

        // Iterate and deploy each aggregator
        uint256 aggCount = discountRateRelayerData.aggregatorData.length;
        for (uint256 aggIndex = 0; aggIndex < aggCount; aggIndex++) {
            deployDiscountRateAggregator(
                discountRateRelayerData.aggregatorData[aggIndex],
                discountRateRelayerAddress
            );
        }

        return discountRateRelayerAddress;
    }

    /// @notice Deploys a full Spot Price Relayer architecture, can contain Aggregator Oracles and Oracles
    /// @param spotPriceRelayerDataEncoded_ ABI encoded RelayerDeployData struct
    /// @param collybusAddress_ Collybus address
    /// @dev Reverts on dependency checks and conditions
    /// @return Returns the Spot Price Relayer
    function deploySpotPriceArchitecture(
        bytes memory spotPriceRelayerDataEncoded_,
        address collybusAddress_
    ) public checkCaller returns (address) {
        RelayerDeployData memory spotPriceRelayerData = abi.decode(
            spotPriceRelayerDataEncoded_,
            (RelayerDeployData)
        );

        // Create the relayer and cache the address
        address spotPriceRelayerAddress = deployCollybusSpotPriceRelayer(
            collybusAddress_
        );

        // Iterate and deploy each aggregator
        uint256 aggCount = spotPriceRelayerData.aggregatorData.length;
        for (uint256 aggIndex = 0; aggIndex < aggCount; aggIndex++) {
            deploySpotPriceAggregator(
                spotPriceRelayerData.aggregatorData[aggIndex],
                spotPriceRelayerAddress
            );
        }

        return spotPriceRelayerAddress;
    }
}
