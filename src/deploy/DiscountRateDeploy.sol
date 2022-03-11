// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IVault} from "../oracle_implementations/discount_rate/ElementFi/IVault.sol";
import {RelayerDeployData, AggregatorData, OracleData, ElementVPData, Factory} from "../factory/Factory.sol";

import "prb-math/contracts/PRBMathSD59x18.sol";

interface IConvergentCurvePool {
    function bond() external view returns (IERC20);

    function underlying() external view returns (IERC20);

    function unitSeconds() external view returns (uint256);

    function expiration() external view returns (uint256);

    function getVault() external view returns (IVault);

    function getPoolId() external view returns (bytes32);
}

contract DiscountRateDeploy {
    function createDeployData(address convergentCurvePoolAddress_)
        external
        view
        returns (bytes memory)
    {
        IConvergentCurvePool pool = IConvergentCurvePool(
            convergentCurvePoolAddress_
        );
        int256 unitSeconds = int256(pool.unitSeconds());
        int256 timeScale59x18 = PRBMathSD59x18.div(
            PRBMathSD59x18.SCALE,
            PRBMathSD59x18.fromInt(unitSeconds)
        );

        ElementVPData memory elementValueProvider = ElementVPData({
            poolId: pool.getPoolId(),
            balancerVault: address(pool.getVault()),
            poolToken: convergentCurvePoolAddress_,
            underlier: address(pool.underlying()),
            ePTokenBond: address(pool.bond()),
            timeScale: timeScale59x18,
            maturity: pool.expiration()
        });

        OracleData memory elementOracleData = OracleData({
            valueProviderData: abi.encode(elementValueProvider),
            timeWindow: 60,
            maxValidTime: 600,
            alpha: 200000000000000000,
            valueProviderType: uint8(Factory.ValueProviderType.Element)
        });

        ElementVPData memory mockedElementValueProvider = ElementVPData({
            poolId: pool.getPoolId(),
            balancerVault: address(pool.getVault()),
            poolToken: address(0x25d7b0bBe1817Dc232523FaD2A7Fbe04EdeB2E25),
            underlier: address(pool.underlying()),
            ePTokenBond: address(pool.bond()),
            timeScale: timeScale59x18,
            maturity: pool.expiration()
        });

        OracleData memory mockOracleData = OracleData({
            valueProviderData: abi.encode(mockedElementValueProvider),
            timeWindow: 60,
            maxValidTime: 600,
            alpha: 200000000000000000,
            valueProviderType: uint8(Factory.ValueProviderType.Element)
        });

        AggregatorData memory elementAggregator = AggregatorData({
            encodedTokenId: bytes32(uint256(1)),
            oracleData: new bytes[](3),
            requiredValidValues: 1,
            minimumPercentageDeltaValue: 1
        });

        elementAggregator.oracleData[0] = abi.encode(elementOracleData);
        elementAggregator.oracleData[1] = abi.encode(elementOracleData);
        elementAggregator.oracleData[2] = abi.encode(mockOracleData);

        RelayerDeployData memory deployData;
        deployData.aggregatorData = new bytes[](1);
        deployData.aggregatorData[0] = abi.encode(elementAggregator);

        return abi.encode(deployData);
    }
}
