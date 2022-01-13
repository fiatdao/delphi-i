// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import {IRelayer} from "src/relayer/IRelayer.sol";
import {IOracle} from "src/oracle/IOracle.sol";
import {ICollybus} from "src/relayer/ICollybus.sol";
import {Guarded} from "src/guarded/Guarded.sol";

// @notice Emitted when trying to add an oracle that already exists
error CollybusDiscountRateRelayer__addOracle_oracleAlreadyRegistered(
    address oracle
);

// @notice Emitted when trying to add an oracle for a tokenId that already has a registered oracle.
error CollybusDiscountRateRelayer__addOracle_tokenIdHasOracleRegistered(
    address oracle,
    uint256 tokenId
);

error CollybusDiscountRateRelayer__removeOracle_oracleNotRegistered(
    address oracle
);

contract CollybusDiscountRateRelayer is Guarded, IRelayer {
    struct OracleData {
        bool exists;
        uint256 tokenId;
        int256 lastUpdateValue;
        uint256 minimumThresholdValue;
    }

    ICollybus private _collybus;

    mapping(address => OracleData) private _oracles;
    mapping(uint256 => bool) private _tokenIdHasOracle;
    address[] private _oracleAddressIndexes;

    constructor(address collybusAddress_) {
        _collybus = ICollybus(collybusAddress_);
    }

    /// @notice Returns the number of oracles
    function oracleCount() public view returns (uint256) {
        return _oracleAddressIndexes.length;
    }

    function oracleAdd(
        address oracle_,
        uint256 tokenId_,
        uint256 minimumThresholdValue_
    ) public checkCaller {
        if (oracleExists(oracle_)) {
            revert CollybusDiscountRateRelayer__addOracle_oracleAlreadyRegistered(
                oracle_
            );
        }

        if (_tokenIdHasOracle[tokenId_]) {
            revert CollybusDiscountRateRelayer__addOracle_tokenIdHasOracleRegistered(
                oracle_,
                tokenId_
            );
        }

        _oracleAddressIndexes.push(oracle_);
        _tokenIdHasOracle[tokenId_] = true;

        _oracles[oracle_] = OracleData({
            exists: true,
            lastUpdateValue: 0,
            tokenId: tokenId_,
            minimumThresholdValue: minimumThresholdValue_
        });
    }

    function oracleRemove(address oracle_) public checkCaller {
        if (!oracleExists(oracle_)) {
            revert CollybusDiscountRateRelayer__removeOracle_oracleNotRegistered(
                oracle_
            );
        }

        // Reset the tokenId Mapping
        _tokenIdHasOracle[_oracles[oracle_].tokenId] = false;

        // Remove the oracle index from the array by swapping to the last element
        uint256 arrayLength = _oracleAddressIndexes.length;
        if (arrayLength > 1) {
            for (uint256 i = 0; i < arrayLength - 1; i++) {
                if (_oracleAddressIndexes[i] == oracle_) {
                    _oracleAddressIndexes[i] = _oracleAddressIndexes[
                        arrayLength - 1
                    ];
                }
            }
        }

        //delete the last element
        _oracleAddressIndexes.pop();

        // Reset struct to default values
        delete _oracles[oracle_];
    }

    function oracleExists(address oracle_)
        public
        view
        checkCaller
        returns (bool)
    {
        return _oracles[oracle_].exists;
    }

    function check() external override(IRelayer) returns (bool) {
        uint256 arrayLength = _oracleAddressIndexes.length;
        for (uint256 i = 0; i < arrayLength; i++) {
            IOracle(_oracleAddressIndexes[i]).update();
            (int256 rate, bool isValid) = IOracle(_oracleAddressIndexes[i])
                .value();
            if (!isValid) continue;

            if (
                absDelta(
                    _oracles[_oracleAddressIndexes[i]].lastUpdateValue,
                    rate
                ) >= _oracles[_oracleAddressIndexes[i]].minimumThresholdValue
            ) {
                return true;
            }
        }

        return false;
    }

    function execute() public override(IRelayer) {
        // Update Collybus all tokenIds with the new discount rate
        uint256 arrayLength = _oracleAddressIndexes.length;
        for (uint256 i = 0; i < arrayLength; i++) {
            IOracle(_oracleAddressIndexes[i]).update();
            (int256 rate, bool isValid) = IOracle(_oracleAddressIndexes[i])
                .value();

            if (!isValid) continue;

            OracleData memory oracleData = _oracles[_oracleAddressIndexes[i]];
            if (
                absDelta(oracleData.lastUpdateValue, rate) >
                oracleData.minimumThresholdValue
            ) {
                oracleData.lastUpdateValue = rate;
                _oracles[_oracleAddressIndexes[i]] = oracleData;
                _collybus.updateDiscountRate(oracleData.tokenId, rate);
            }
        }
    }

    function absDelta(int256 a, int256 b) internal pure returns (uint256) {
        if (a > b) {
            return uint256(a - b);
        }
        return uint256(b - a);
    }
}
