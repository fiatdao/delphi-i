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
import {CollybusDiscountRateRelayer} from "src/relayer/CollybusDiscountRate/CollybusDiscountRateRelayer.sol";
import {CollybusSpotPriceRelayer} from "src/relayer/CollybusSpotPrice/CollybusSpotPriceRelayer.sol";

struct OracleData {
    address aggregatorAddress;
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
    NotionalVPData notionalData;
    OracleData oracleData;
}

struct AggregatorData {
    uint256 tokenId;
    bytes[] oracleData;
    address relayerAddress;
}

struct DiscountRateDeployData {
    bytes[] notionalData;
    bytes[] elementData;
    address discountRateRelayerAddress;
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

    function deployDiscountRate(DiscountRateDeployData memory deployData)
        public
        returns (address)
    {
        return address(0);
    }
}
