// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;
pragma experimental ABIEncoderV2;

import {IOracle} from "src/oracle/IOracle.sol";
import {Oracle} from "src/oracle/Oracle.sol";
import {AggregatorOracle} from "src/aggregator/AggregatorOracle.sol";
import {IAggregatorOracle} from "src/aggregator/IAggregatorOracle.sol";

// Value providers
import {ElementFiValueProvider} from "src/valueprovider/ElementFi/ElementFiValueProvider.sol";
import {NotionalFinanceValueProvider} from "src/valueprovider/NotionalFinance/NotionalFinanceValueProvider.sol";

// Relayers
import {ICollybusDiscountRateRelayer} from "src/relayer/CollybusDiscountRate/ICollybusDiscountRateRelayer.sol";
import {CollybusDiscountRateRelayer} from "src/relayer/CollybusDiscountRate/CollybusDiscountRateRelayer.sol";
import {CollybusSpotPriceRelayer} from "src/relayer/CollybusSpotPrice/CollybusSpotPriceRelayer.sol";

// @notice Emitter when the collybus address is address(0)
error Factory__deployDiscountRateArchitecture_invalidCollybusAddress();

// @notice Emitted if no value provider is found for given providerType
error Factory__deployValueProvider_invalidValueProviderType();

/// @notice Data structure that wraps data needed to deploy an Element Value Provider contract
struct ElementVPData {
    bytes32 poolId;
    address balancerVault;
    address poolToken;
    uint256 poolTokenDecimals;
    address underlier;
    uint256 underlierDecimals;
    address ePTokenBond;
    uint256 ePTokenBondDecimals;
    int256 unitSeconds;
    uint256 maturity;
}

/// @notice Data structure that wraps data needed to deploy an Notional Value Provider contract
struct NotionalVPData {
    address notionalViewAddress;
    uint16 currencyID;
    uint256 lastImpliedRateDecimals;
    uint256 maturity;
    uint256 settlementDate;
}

/// @notice Data structure that wraps needed data to deploy an Oracle contract
/// @dev The value provider data field is a abi.encoded struct based on the given providerType
/// @dev The Factory will revert if the providerType is not found
struct OracleData {
    bytes valueProviderData;
    uint8 providerType;
    uint256 timeWindow;
    uint256 maxValidTime;
    int256 alpha;
}

/// @notice Data structure that wraps needed data to deploy an Oracle Aggregator contract
/// @dev The oracleData array field contains abi.encoded OracleData structures
/// @dev Factory will revert if the requiredValidValues is bigger than the oracleData item count
struct AggregatorData {
    uint256 tokenId;
    bytes[] oracleData;
    uint256 requiredValidValues;
    uint256 minimumThresholdValue;
}

/// @notice Data structure that wraps needed data to deploy a full Discount Rate Relayer architecture
/// @dev The aggregatorData field contains abi.encoded AggregatorData structures
/// @dev Factory will revert if the aggregators do not contain unique tokenId's
struct DiscountRateDeployData {
    bytes[] aggregatorData;
}

contract Factory {
    enum ValueProviderType {
        Notional,
        Element
    }

    /// @notice Deploys an Element Finance Value Provider
    /// @dev For more information about the params please check the Value Provider Contract
    /// todo: add the master github path to contract
    /// @return Returns the address of the new value provider
    function deployElementFiValueProvider(
        bytes32 poolId_,
        address balancerVault_,
        address poolToken_,
        uint256 poolTokenDecimals_,
        address underlier_,
        uint256 underlierDecimals_,
        address ePTokenBond_,
        uint256 ePTokenBondDecimals_,
        int256 timeScale_,
        uint256 maturity_
    ) public returns (address) {
        ElementFiValueProvider elementFiValueProvider = new ElementFiValueProvider(
                poolId_,
                balancerVault_,
                poolToken_,
                poolTokenDecimals_,
                underlier_,
                underlierDecimals_,
                ePTokenBond_,
                ePTokenBondDecimals_,
                timeScale_,
                maturity_
            );

        return address(elementFiValueProvider);
    }

    /// @notice Deploys an Notional Finance Value Provider
    /// @dev For more information about the params please check the Value Provider Contract
    /// todo: add the master github path to contract
    /// @return Returns the address of the new value provider
    function deployNotionalFinanceProvider(
        address notionalViewAddress_,
        uint16 currencyId_,
        uint256 lastImpliedRateDecimals_,
        uint256 maturityDate_,
        uint256 settlementDate_
    ) public returns (address) {
        NotionalFinanceValueProvider notionalFinanceValueProvider = new NotionalFinanceValueProvider(
                notionalViewAddress_,
                currencyId_,
                lastImpliedRateDecimals_,
                maturityDate_,
                settlementDate_
            );

        return address(notionalFinanceValueProvider);
    }

    /// @notice Deploys a new Value Provider contract
    /// @param valueProviderDataEncoded_ Abi encoded Value Provider data structure
    /// @param valueProviderType_ Type used to decode the given data structure
    /// @dev Reverts if valueProviderType_ is not recognized
    /// @dev Reverts if the encoded struct and type do not match
    /// @return Returns the address of the new value provider
    function deployValueProvider(
        bytes memory valueProviderDataEncoded_,
        uint8 valueProviderType_
    ) public returns (address) {
        if (valueProviderType_ == uint8(ValueProviderType.Notional)) {
            // Decode the given struct
            // This will revert if there's a missmatch between the valueProviderType_ and encoded bytes
            NotionalVPData memory notionalData = abi.decode(
                valueProviderDataEncoded_,
                (NotionalVPData)
            );

            // Create and return the value provider
            address notionalVP = deployNotionalFinanceProvider(
                notionalData.notionalViewAddress,
                notionalData.currencyID,
                notionalData.lastImpliedRateDecimals,
                notionalData.maturity,
                notionalData.settlementDate
            );

            return notionalVP;
        }

        if (valueProviderType_ == uint8(ValueProviderType.Element)) {
            // Decode the given struct
            // This will revert if there's a missmatch between the valueProviderType_ and encoded bytes
            ElementVPData memory elementData = abi.decode(
                valueProviderDataEncoded_,
                (ElementVPData)
            );

            // Create and return the value provider
            address elementVP = deployElementFiValueProvider(
                elementData.poolId,
                elementData.balancerVault,
                elementData.poolToken,
                elementData.poolTokenDecimals,
                elementData.underlier,
                elementData.underlierDecimals,
                elementData.ePTokenBond,
                elementData.ePTokenBondDecimals,
                elementData.unitSeconds,
                elementData.maturity
            );

            return elementVP;
        }

        // Revert if the value provider type is not supported
        revert Factory__deployValueProvider_invalidValueProviderType();
    }

    /// @notice Deploys a new Oracle and adds it to an Aggregator
    /// @param oracleDataEncoded_ Abi encoded Oracle data structure
    /// @param aggregatorAddress_ The aggregator address that will contain the created Oracle
    /// @dev Reverts if the encoded struct can not be decoded
    /// @return Returns the address of the new Oracle
    function deployOracle(
        bytes memory oracleDataEncoded_,
        address aggregatorAddress_
    ) public returns (address) {
        // Decode the oracle data
        OracleData memory oracleData = abi.decode(
            oracleDataEncoded_,
            (OracleData)
        );

        // We deploy the value provider needed by the oracle
        address valueProviderAddress = deployValueProvider(
            oracleData.valueProviderData,
            oracleData.providerType
        );

        // Deploy the oracle and use the new value provider
        Oracle oracle = new Oracle(
            valueProviderAddress,
            oracleData.timeWindow,
            oracleData.maxValidTime,
            oracleData.alpha
        );

        // Add the oracle to the Aggregator Oracle
        IAggregatorOracle(aggregatorAddress_).oracleAdd(address(oracle));

        return address(oracle);
    }

    /// @notice Deploys a new Aggregator and adds it to a Relayer
    /// @param aggregatorDataEncoded_ Abi encoded Oracle data structure
    /// @param discountRateRelayerAddress_ The address of the discount rate relayer where we will add the aggregator
    /// @dev Reverts if the encoded struct can not be decoded
    /// @return Returns the address of the new Aggregator
    function deployAggregator(
        bytes memory aggregatorDataEncoded_,
        address discountRateRelayerAddress_
    ) public returns (address) {
        // Create the aggregator contract
        AggregatorOracle aggregatorOracle = new AggregatorOracle();

        // Decode each input notional aggregator structure
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
            deployOracle(
                aggData.oracleData[oracleIndex],
                address(aggregatorOracle)
            );
        }

        // Set the minimim required valid values for the aggregator
        // Reverts if the requiredValidValues is bigger than the oracleCount
        aggregatorOracle.setParam(
            "requiredValidValues",
            aggData.requiredValidValues
        );

        // Add the aggregator to the relayer
        // Reverts if the tokenId is not unique
        // Revert if the address of the Aggregator is already used
        ICollybusDiscountRateRelayer(discountRateRelayerAddress_).oracleAdd(
            address(aggregatorOracle),
            aggData.tokenId,
            aggData.minimumThresholdValue
        );

        return address(aggregatorOracle);
    }

    /// @notice Deploys a new Discount Rate Relayer
    /// @param collybus_ Address for the collybus
    /// @return Returns the address of the Relayer
    function deployCollybusDiscountRateRelayer(address collybus_)
        public
        returns (address)
    {
        CollybusDiscountRateRelayer discountRateRelayer = new CollybusDiscountRateRelayer(
                collybus_
            );
        return address(discountRateRelayer);
    }

    /// @notice Deploys a new Spot Price Relayer
    /// @param collybus_ Address for the collybus
    /// @return Returns the address of the Relayer
    function deployCollybusSpotPriceRelayer(address collybus_)
        public
        returns (address)
    {
        CollybusSpotPriceRelayer spotPriceRelayer = new CollybusSpotPriceRelayer(
                collybus_
            );
        return address(spotPriceRelayer);
    }

    /// @notice Deploys a full Discount Rate Relayer architecture, can contain Aggregator Oracles and Oracles
    /// @param discountRateRelayerDataEncoded_ Abi encoded DiscountRateDeployData struct
    /// @param collybusAddress_ Collybus address.
    /// @dev Reverts on dependencies checks and conditions.
    /// @return Returns the address of the Discount Rate Relayer
    function deployDiscountRateArchitecture(
        DiscountRateDeployData memory discountRateRelayerDataEncoded_,
        address collybusAddress_
    ) public returns (address) {
        // The Collybus address is needed in order to deploy the Discount Rate Relayer
        if (collybusAddress_ == address(0)) {
            revert Factory__deployDiscountRateArchitecture_invalidCollybusAddress();
        }

        // Create the relayer and cache the address
        address discountRateRelayerAddress = deployCollybusDiscountRateRelayer(
            collybusAddress_
        );

        // Iterate and deploy each aggregator
        uint256 aggCount = discountRateRelayerDataEncoded_
            .aggregatorData
            .length;
        for (uint256 aggIndex = 0; aggIndex < aggCount; aggIndex++) {
            deployAggregator(
                discountRateRelayerDataEncoded_.aggregatorData[aggIndex],
                discountRateRelayerAddress
            );
        }

        return discountRateRelayerAddress;
    }
}
