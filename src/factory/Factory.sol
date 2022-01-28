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

struct OracleData {
    uint256 timeWindow;
    uint256 maxValidTime;
    int256 alpha;
}

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

struct ElementData {
    ElementVPData vpData;
    OracleData oracleData;
}

struct NotionalData {
    NotionalVPData vpData;
    OracleData oracleData;
}

struct AggregatorData {
    uint256 tokenId;
    bytes[] oracleData;
    uint256 requiredValidValues;
    uint256 minimumThresholdValue;
    address aggregatorAddress;
}

struct DiscountRateDeployData {
    bytes[] notionalData;
    bytes[] elementData;
    address discountRateRelayerAddress;
    address collybusAddress;
}

contract Factory {
    function deployOracle(
        address valueProvider_,
        uint256 timeUpdateWindow_,
        uint256 maxValidTime_,
        int256 alpha_
    ) public returns (address) {
        Oracle oracle = new Oracle(
            valueProvider_,
            timeUpdateWindow_,
            maxValidTime_,
            alpha_
        );

        return address(oracle);
    }

    function deployAggregator(
        address[] memory oracles_,
        uint256 requiredValidValues_
    ) public returns (address) {
        AggregatorOracle aggregatorOracle = new AggregatorOracle();

        // Add the list of oracles
        for (uint256 i = 0; i < oracles_.length; i++) {
            aggregatorOracle.oracleAdd(oracles_[i]);
        }

        // Set the required number of valid values
        aggregatorOracle.setParam("requiredValidValues", requiredValidValues_);

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
        DiscountRateDeployData memory deployData
    ) public returns (address) {
        // Check if we need to create the Discount Rate Relayer
        address discountRateRelayerAddress = deployData
            .discountRateRelayerAddress;
        bool createRelayer = discountRateRelayerAddress == address(0);
        if (createRelayer) {
            // The Collybus address is needed in order to deploy the Discount Rate Relayer
            if (deployData.collybusAddress == address(0)) {
                revert Factory__deployDiscountRateArchitecture_invalidCollybusAddress();
            }

            // Create the relayer and cache the address
            discountRateRelayerAddress = deployCollybusDiscountRateRelayer(
                deployData.collybusAddress
            );
        }

        // We check if we have any national aggregators to deploy
        uint256 notionalAggregatorCount = deployData.notionalData.length;
        for (
            uint256 notionalAggIndex = 0;
            notionalAggIndex < notionalAggregatorCount;
            notionalAggIndex++
        ) {
            // Decode each input notional aggregator structure
            AggregatorData memory aggData = abi.decode(
                deployData.notionalData[notionalAggIndex],
                (AggregatorData)
            );

            address agregatorAddress = aggData.aggregatorAddress;
            //Check where we need to create the aggregator
            bool createTheAggregator = createRelayer ||
                (agregatorAddress == address(0));

            // For each Notional aggregator we find we will go though the oracles and create each one
            uint256 notionalOracleCount = aggData.oracleData.length;

            // We will need to store the created oracles in order to deploy the aggregator
            // This list will not be used if we already have a deployed aggregator
            address[] memory oracleList;

            if (createTheAggregator) {
                oracleList = new address[](notionalOracleCount);
            }

            for (
                uint256 notionalOracleIndex = 0;
                notionalOracleIndex < notionalOracleCount;
                notionalOracleIndex++
            ) {
                NotionalData memory notionalData = abi.decode(
                    aggData.oracleData[notionalOracleIndex],
                    (NotionalData)
                );

                address notionalVP = deployNotionalFinanceProvider(
                    notionalData.vpData.notionalViewAddress,
                    notionalData.vpData.currencyID,
                    notionalData.vpData.maturity,
                    notionalData.vpData.settlementDate
                );

                address oracleAddress = deployOracle(
                    notionalVP,
                    notionalData.oracleData.timeWindow,
                    notionalData.oracleData.maxValidTime,
                    notionalData.oracleData.alpha
                );

                if (createTheAggregator) {
                    oracleList[notionalOracleIndex] = oracleAddress;
                } else {
                    IAggregatorOracle(agregatorAddress).oracleAdd(
                        oracleAddress
                    );
                }
            }

            if (createTheAggregator) {
                agregatorAddress = deployAggregator(
                    oracleList,
                    aggData.requiredValidValues
                );

                ICollybusDiscountRateRelayer(discountRateRelayerAddress)
                    .oracleAdd(
                        agregatorAddress,
                        aggData.tokenId,
                        aggData.minimumThresholdValue
                    );
            }
        }

        // We check if we have any element aggregators to deploy
        uint256 elementAggregatorCount = deployData.elementData.length;
        for (
            uint256 elementAggIndex = 0;
            elementAggIndex < elementAggregatorCount;
            elementAggIndex++
        ) {
            // Decode each input aggregator structure
            AggregatorData memory aggData = abi.decode(
                deployData.elementData[elementAggIndex],
                (AggregatorData)
            );

            address agregatorAddress = aggData.aggregatorAddress;
            //Check where we need to create the aggregator
            bool createTheAggregator = createRelayer ||
                (agregatorAddress == address(0));

            // For each aggregator we find we will go though the oracles and create each one
            uint256 elementOracleCount = aggData.oracleData.length;

            // We will need to store the created oracles in order to deploy the aggregator
            // This list will not be used if we already have a deployed aggregator
            address[] memory oracleList;

            if (createTheAggregator) {
                oracleList = new address[](elementOracleCount);
            }

            for (
                uint256 elementOracleIndex = 0;
                elementOracleIndex < elementOracleCount;
                elementOracleIndex++
            ) {
                ElementData memory elementData = abi.decode(
                    aggData.oracleData[elementOracleIndex],
                    (ElementData)
                );

                address elementVP = deployElementFinanceValueProvider(
                    elementData.vpData.poolId,
                    elementData.vpData.balancerVault,
                    elementData.vpData.underlier,
                    elementData.vpData.ePTokenBond,
                    elementData.vpData.timeToMaturity,
                    elementData.vpData.unitSeconds
                );

                address oracleAddress = deployOracle(
                    elementVP,
                    elementData.oracleData.timeWindow,
                    elementData.oracleData.maxValidTime,
                    elementData.oracleData.alpha
                );

                if (createTheAggregator) {
                    oracleList[elementOracleIndex] = oracleAddress;
                } else {
                    IAggregatorOracle(agregatorAddress).oracleAdd(
                        oracleAddress
                    );
                }
            }

            if (createTheAggregator) {
                agregatorAddress = deployAggregator(
                    oracleList,
                    aggData.requiredValidValues
                );

                ICollybusDiscountRateRelayer(discountRateRelayerAddress)
                    .oracleAdd(
                        agregatorAddress,
                        aggData.tokenId,
                        aggData.minimumThresholdValue
                    );
            }
        }

        return discountRateRelayerAddress;
    }
}
