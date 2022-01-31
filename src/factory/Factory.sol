// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;
pragma experimental ABIEncoderV2;

import {IOracle} from "src/oracle/IOracle.sol";
import {Oracle} from "src/oracle/Oracle.sol";
import {AggregatorOracle} from "src/aggregator/AggregatorOracle.sol";
import {IAggregatorOracle} from "src/aggregator/IAggregatorOracle.sol";

// Value providers
import {ElementFinanceValueProvider} from "src/valueprovider/ElementFinance/ElementFinanceValueProvider.sol";
import {NotionalFinanceValueProvider} from "src/valueprovider/NotionalFinance/NotionalFinanceValueProvider.sol";

// Relayers
import {ICollybusDiscountRateRelayer} from "src/relayer/CollybusDiscountRate/ICollybusDiscountRateRelayer.sol";
import {CollybusDiscountRateRelayer} from "src/relayer/CollybusDiscountRate/CollybusDiscountRateRelayer.sol";
import {CollybusSpotPriceRelayer} from "src/relayer/CollybusSpotPrice/CollybusSpotPriceRelayer.sol";

// @notice Emitter when the collybus address is address(0)
error Factory__deployDiscountRateArchitecture_invalidCollybusAddress();

error Factory__deployValueProvider_invalidValueProviderType();

struct ElementVPData {
    bytes32 poolId;
    address balancerVault;
    address underlier;
    address ePTokenBond;
    uint256 timeToMaturity;
    uint256 unitSeconds;
}

struct NotionalVPData {
    address notionalViewAddress;
    uint16 currencyID;
    uint256 maturity;
    uint256 settlementDate;
}

struct OracleData {
    bytes valueProviderData;
    uint8 providerType;

    uint256 timeWindow;
    uint256 maxValidTime;
    int256 alpha;
}

struct AggregatorData {
    uint256 tokenId;
    
    bytes[] oracleData;
    uint256 requiredValidValues;
    uint256 minimumThresholdValue;
}

struct DiscountRateDeployData {
    bytes[] aggregatorData;
}

contract Factory {

    enum ValueProviderType{
        Notional,
        Element
    }

    function deployOracle(
        bytes memory oracleDataEncoded,
        address aggregatorAddress
    ) public returns (address) {

        OracleData memory oracleData = abi.decode(
            oracleDataEncoded,
            (OracleData)
        );

        address valueProviderAddress = deployValueProvider(oracleData.valueProviderData, oracleData.providerType);

        Oracle oracle = new Oracle(
            valueProviderAddress,
            oracleData.timeWindow,
            oracleData.maxValidTime,
            oracleData.alpha
        );

        IAggregatorOracle(aggregatorAddress).oracleAdd(address(oracle));

        return address(oracle);
    }

    function deployValueProvider(bytes memory valueProviderData, uint8 valueProviderType) public returns (address)
    {
        if (valueProviderType == uint8(ValueProviderType.Notional)){

            NotionalVPData memory notionalData = abi.decode(
            valueProviderData,
            (NotionalVPData)
            );

            address notionalVP = deployNotionalFinanceProvider(
                notionalData.notionalViewAddress,
                notionalData.currencyID,
                notionalData.maturity,
                notionalData.settlementDate
            );

            return notionalVP;
        }

        if (valueProviderType == uint8(ValueProviderType.Element)){
            ElementVPData memory elementData = abi.decode(
            valueProviderData,
            (ElementVPData)
            );

            address elementVP = deployElementFinanceValueProvider(
                elementData.poolId,
                elementData.balancerVault,
                elementData.underlier,
                elementData.ePTokenBond,
                elementData.timeToMaturity,
                elementData.unitSeconds
            );

            return elementVP;
        }

        revert Factory__deployValueProvider_invalidValueProviderType();
    }

    function deployAggregator(bytes memory data, address discountRateRelayerAddress) public returns (address) 
    {
        AggregatorOracle aggregatorOracle = new AggregatorOracle();

        // Decode each input notional aggregator structure
        AggregatorData memory aggData = abi.decode(
            data,
            (AggregatorData)
        );

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

        aggregatorOracle.setParam("requiredValidValues", aggData.requiredValidValues);

        ICollybusDiscountRateRelayer(discountRateRelayerAddress).oracleAdd(
            address(aggregatorOracle),
            aggData.tokenId,
            aggData.minimumThresholdValue
        );

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

    function deployNotionalFinanceProvider(
        address notionalViewAddress_,
        uint16 currencyId_,
        uint256 maturityDate_,
        uint256 settlementDate_
    ) public returns (address) {
        NotionalFinanceValueProvider notionalFinanceValueProvider = new NotionalFinanceValueProvider(
                notionalViewAddress_,
                currencyId_,
                maturityDate_,
                settlementDate_
            );

        return address(notionalFinanceValueProvider);
    }

    function deployCollybusDiscountRateRelayer(address collybus_)
        public
        returns (address)
    {
        CollybusDiscountRateRelayer discountRateRelayer = new CollybusDiscountRateRelayer(
                collybus_
            );
        return address(discountRateRelayer);
    }

    function deployCollybusSpotPriceRelayer(address collybus_)
        public
        returns (address)
    {
        CollybusSpotPriceRelayer spotPriceRelayer = new CollybusSpotPriceRelayer(
                collybus_
            );
        return address(spotPriceRelayer);
    }

    function deployDiscountRateArchitecture(
        DiscountRateDeployData memory deployData,
        address collybusAddress
    ) public returns (address) {
        // The Collybus address is needed in order to deploy the Discount Rate Relayer
        if (collybusAddress == address(0)) {
            revert Factory__deployDiscountRateArchitecture_invalidCollybusAddress();
        }

        // Create the relayer and cache the address
        address discountRateRelayerAddress = deployCollybusDiscountRateRelayer(
            collybusAddress
        );
        
        // We check if we have any national aggregators to deploy
        uint256 aggCount = deployData.aggregatorData.length;
        for (
            uint256 aggIndex = 0;
            aggIndex < aggCount;
            aggIndex++
        ) {
            deployAggregator(deployData.aggregatorData[aggIndex],discountRateRelayerAddress);
        }

        return discountRateRelayerAddress;
    }
}