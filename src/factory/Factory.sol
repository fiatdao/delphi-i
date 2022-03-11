// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import {IOracle} from "../oracle/IOracle.sol";
import {IAggregatorOracle} from "../aggregator/IAggregatorOracle.sol";
// Contract Deployers
import {IElementFiValueProviderFactory} from "./ElementFiValueProviderFactory.sol";
import {INotionalFinanceValueProviderFactory} from "./NotionalFinanceValueProviderFactory.sol";
import {IYieldValueProviderFactory} from "./YieldValueProviderFactory.sol";
import {IChainlinkValueProviderFactory} from "./ChainlinkValueProviderFactory.sol";
import {IAggregatorOracleFactory} from "./AggregatorOracleFactory.sol";
import {IRelayerFactory} from "./RelayerFactory.sol";
import {IRelayer} from "../relayer/IRelayer.sol";
import {Guarded} from "../guarded/Guarded.sol";

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
    uint256 valueProviderType;
    uint256 timeWindow;
    uint256 maxValidTime;
    int256 alpha;
}

/// @notice Data structure that wraps needed data to deploy an Oracle Aggregator contract
/// @dev The oracleData array field contains abi.encoded OracleData structures
/// @dev Factory will revert if the requiredValidValues is bigger than the oracleData item count
struct AggregatorData {
    bytes32 encodedTokenId;
    bytes[] oracleData;
    uint256 requiredValidValues;
    uint256 minimumPercentageDeltaValue;
}

/// @notice Data structure that wraps needed data to deploy a full Relayer architecture
/// @dev The aggregatorData field contains abi.encoded AggregatorData structure
/// @dev Factory will revert if the aggregators do not contain unique tokenId's
struct RelayerDeployData {
    bytes[] aggregatorData;
}

contract Factory is Guarded {
    event RelayerDeployed(
        address relayerAddress,
        IRelayer.RelayerType relayerType
    );
    event AggregatorDeployed(address aggregatorAddress);
    event OracleDeployed(address oracleAddress);

    // @notice Emitted when the collybus address is address(0)
    error Factory__deployRelayer_invalidCollybusAddress();

    // @notice Emitted if no value provider is found for given providerType
    error Factory__deployOracle_invalidValueProviderType(uint256);

    // Supported value provider oracle types
    enum ValueProviderType {
        Element,
        Notional,
        Yield,
        Chainlink,
        COUNT
    }

    address public immutable elementFiValueProviderFactory;
    address public immutable notionalValueProviderFactory;
    address public immutable yieldValueProviderFactory;
    address public immutable chainlinkValueProviderFactory;
    address public immutable aggregatorOracleFactory;
    address public immutable relayerFactory;

    constructor(
        address elementFiValueProviderFactory_,
        address notionalValueProviderFactory_,
        address yieldValueProviderFactory_,
        address chainlinkValueProviderFactory_,
        address aggregatorOracleFactory_,
        address relayerFactory_
    ) {
        elementFiValueProviderFactory = elementFiValueProviderFactory_;
        notionalValueProviderFactory = notionalValueProviderFactory_;
        yieldValueProviderFactory = yieldValueProviderFactory_;
        chainlinkValueProviderFactory = chainlinkValueProviderFactory_;
        aggregatorOracleFactory = aggregatorOracleFactory_;
        relayerFactory = relayerFactory_;
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

        address elementFiValueProviderAddress = IElementFiValueProviderFactory(
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

        address notionalFinanceValueProviderAddress = INotionalFinanceValueProviderFactory(
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

        address yieldValueProviderAddress = IYieldValueProviderFactory(
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

        address chainlinkValueProviderAddress = IChainlinkValueProviderFactory(
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
        if (
            oracleData.valueProviderType == uint256(ValueProviderType.Element)
        ) {
            // Create the value provider
            oracleAddress = deployElementFiValueProvider(oracleData);
        } else if (
            oracleData.valueProviderType == uint256(ValueProviderType.Notional)
        ) {
            // Create the value provider
            oracleAddress = deployNotionalFinanceValueProvider(oracleData);
        } else if (
            oracleData.valueProviderType == uint256(ValueProviderType.Chainlink)
        ) {
            // Create the value provider
            oracleAddress = deployChainlinkValueProvider(oracleData);
        } else if (
            oracleData.valueProviderType == uint256(ValueProviderType.Yield)
        ) {
            // Create the value provider
            oracleAddress = deployYieldValueProvider(oracleData);
        } else {
            // Revert if the value provider type is not supported
            revert Factory__deployOracle_invalidValueProviderType(
                oracleData.valueProviderType
            );
        }

        // Whitelist the aggregator so it can Update the oracle
        Guarded(oracleAddress).allowCaller(
            Guarded(oracleAddress).ANY_SIG(),
            aggregatorAddress_
        );
        // Add the oracle to the Aggregator Oracle
        IAggregatorOracle(aggregatorAddress_).oracleAdd(oracleAddress);
        emit OracleDeployed(oracleAddress);

        return oracleAddress;
    }

    /// @notice Deploys a new Aggregator and adds it to a Relayer
    /// @param aggregatorDataEncoded_ ABI encoded Aggregator data structure
    /// @param relayerAddress_ The address of the discount rate relayer where we will add the aggregator
    /// @dev Reverts if the encoded struct can not be decoded
    /// @return Returns the address of the new Aggregator
    function deployAggregator(
        bytes memory aggregatorDataEncoded_,
        address relayerAddress_
    ) public checkCaller returns (address) {
        // Create aggregator contract
        address aggregatorOracleAddress = IAggregatorOracleFactory(
            aggregatorOracleFactory
        ).create();

        // Decode aggregator structure
        AggregatorData memory aggData = abi.decode(
            aggregatorDataEncoded_,
            (AggregatorData)
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

        // Whitelist the relayer so it can Update the aggregator
        Guarded(aggregatorOracleAddress).allowCaller(
            Guarded(aggregatorOracleAddress).ANY_SIG(),
            relayerAddress_
        );

        // Add the aggregator to the relayer
        // Reverts if the tokenId is not unique
        // Reverts if the Aggregator is already used
        IRelayer(relayerAddress_).oracleAdd(
            aggregatorOracleAddress,
            aggData.encodedTokenId,
            aggData.minimumPercentageDeltaValue
        );

        emit AggregatorDeployed(aggregatorOracleAddress);
        return aggregatorOracleAddress;
    }

    /// @notice Deploys a new Discount Rate Relayer
    /// @param collybus_ Address of Collybus
    /// @dev Reverts if Collybus is not set
    /// @return Returns the address of the Relayer
    function deployRelayer(address collybus_, IRelayer.RelayerType type_)
        public
        checkCaller
        returns (address)
    {
        // Collybus address is needed in order to deploy the Discount Rate Relayer
        if (collybus_ == address(0)) {
            revert Factory__deployRelayer_invalidCollybusAddress();
        }

        address relayerAddress = IRelayerFactory(relayerFactory).create(
            collybus_,
            type_
        );

        emit RelayerDeployed(relayerAddress, type_);
        return relayerAddress;
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
        address discountRateRelayerAddress = deployRelayer(
            collybus_,
            IRelayer.RelayerType.DiscountRate
        );

        // Iterate and deploy each aggregator
        uint256 aggCount = discountRateRelayerData.aggregatorData.length;
        for (uint256 aggIndex = 0; aggIndex < aggCount; aggIndex++) {
            deployAggregator(
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
        address spotPriceRelayerAddress = deployRelayer(
            collybusAddress_,
            IRelayer.RelayerType.SpotPrice
        );

        // Iterate and deploy each aggregator
        uint256 aggCount = spotPriceRelayerData.aggregatorData.length;
        for (uint256 aggIndex = 0; aggIndex < aggCount; aggIndex++) {
            deployAggregator(
                spotPriceRelayerData.aggregatorData[aggIndex],
                spotPriceRelayerAddress
            );
        }

        return spotPriceRelayerAddress;
    }

    /// @notice Sets permission on the destination contract
    /// @param where_ What contract to set permission on. This contract needs to implement `Guarded.allowCaller(sig, who)`
    /// @param sig_ Method signature [4byte]
    /// @param who_ Address of who should be able to call `sig_`
    /// @dev Reverts if the current contract can't call `.allowCaller`
    function setPermission(
        address where_,
        bytes32 sig_,
        address who_
    ) public checkCaller {
        Guarded(where_).allowCaller(sig_, who_);
    }

    /// @notice Removes permission on the destination contract
    /// @param where_ What contract to remove permission from. This contract needs to implement `Guarded.blockCaller(sig, who)`
    /// @param sig_ Method signature [4byte]
    /// @param who_ Address of who should not be able to call `sig_`
    /// @dev Reverts if the current contract can't call `.blockCaller`
    function removePermission(
        address where_,
        bytes32 sig_,
        address who_
    ) public checkCaller {
        Guarded(where_).blockCaller(sig_, who_);
    }
}
