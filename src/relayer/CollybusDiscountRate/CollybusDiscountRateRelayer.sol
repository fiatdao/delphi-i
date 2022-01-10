// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import {IRelayer} from "../IRelayer.sol";

contract CollybusDiscountRateRelayer is IRelayer {
    struct OracleData {
        bool exists;
        uint256 rateId;
        int256 lastUpdateValue;
    }

    mapping (address => OracleData) oracles;

    function oracleAdd(address oracle_, uint256 rateId_) public {
        oracles[oracle_] = OracleData({
            exists: true,
            rateId: rateId_,
            lastUpdateValue: 0
        });
    }

    function oracleExists(address oracle_) public returns (bool) {
        return oracles[oracle_].exists;
    }
}
