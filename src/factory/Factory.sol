// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import {IOracle} from "../oracle/IOracle.sol";
// Contract Deployers
import {IElementFiValueProviderFactory} from "./ElementFiValueProviderFactory.sol";
import {INotionalFinanceValueProviderFactory} from "./NotionalFinanceValueProviderFactory.sol";
import {IYieldValueProviderFactory} from "./YieldValueProviderFactory.sol";
import {IChainlinkValueProviderFactory} from "./ChainlinkValueProviderFactory.sol";
import {IRelayerFactory} from "./RelayerFactory.sol";
import {IRelayer} from "../relayer/IRelayer.sol";
import {Guarded} from "../guarded/Guarded.sol";
/*

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
}

/// @notice Data structure that wraps needed data to deploy a full Relayer architecture
/// @dev The aggregatorData field contains abi.encoded AggregatorData structure
/// @dev Factory will revert if the aggregators do not contain unique tokenId's
struct RelayerData {
    bytes oracleData;
    bytes32 encodedTokenId;
    uint256 minimumPercentageDeltaValue;
}

contract Factory is Guarded {
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
        OracleData memory oracleParams_
    ) public checkCaller returns (address) {
        YieldVPData memory yieldParams = abi.decode(
            oracleParams_.valueProviderData,
            (YieldVPData)
        );

        address yieldValueProviderAddress = IYieldValueProviderFactory(
            yieldValueProviderFactory
        ).create(
                oracleParams_.timeWindow,
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
                chainlinkParams.chainlinkAggregatorAddress
            );

        return chainlinkValueProviderAddress;
    }

    /// @notice Deploys a new Oracle
    /// @param oracleDataEncoded_ ABI encoded Oracle data structure
    /// @dev Reverts if the encoded struct can not be decoded
    /// @return Returns the address of the new Oracle
    function deployOracle(
        bytes memory oracleDataEncoded_
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

        return oracleAddress;
    }

    /// @notice Deploys a new Discount Rate Relayer
    /// @param collybus_ Address of Collybus
    /// @dev Reverts if Collybus is not set
    /// @return Returns the address of the Relayer
    function deployRelayer(address collybus_, IRelayer.RelayerType type_, bytes memory relayerData_)
        public
        checkCaller
        returns (address)
    {
        // Decode relayer data
        RelayerData memory relayerData = abi.decode(
            relayerData_,
            (RelayerData)
        );

        address oracleAddress = deployOracle(relayerData.oracleData);

        // Collybus address is needed in order to deploy the Discount Rate Relayer
        if (collybus_ == address(0)) {
            revert Factory__deployRelayer_invalidCollybusAddress();
        }

        address relayerAddress = IRelayerFactory(relayerFactory).create(
            collybus_,
            type_,
            oracleAddress,
            relayerData.encodedTokeId,
            relayerData.minimumPercentageDeltaValue
        );

        return relayerAddress;
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
*/
