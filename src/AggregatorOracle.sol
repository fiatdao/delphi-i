// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import {Guarded} from "lib/fiat-lux/src/Guarded.sol";

// @notice Emitted when trying to add an oracle that already exists
error AggregatorOracle__addOracle_oracleAlreadyRegistered(address oracle);

// @notice Emitted when trying to remove an oracle that does not exist
error AggregatorOracle__removeOracle_oracleNotRegistered(address oracle);

// @notice Emitted when one does not have the right permissions to manage oracles
error AggregatorOracle__notAuthorized();

contract AggregatorOracle is Guarded {
    using EnumerableSet for EnumerableSet.AddressSet;

    EnumerableSet.AddressSet private oracles;

    function oracleCount() public view returns (uint256) {
        return oracles.length();
    }

    function oracleAdd(address oracle) public onlyRoot {
        bool added = oracles.add(oracle);
        if (added == false) {
            revert AggregatorOracle__addOracle_oracleAlreadyRegistered(oracle);
        }
    }

    function oracleExists(address oracle) public view returns (bool) {
        return oracles.contains(oracle);
    }

    function oracleRemove(address oracle) public onlyRoot {
        bool removed = oracles.remove(oracle);
        if (removed == false) {
            revert AggregatorOracle__removeOracle_oracleNotRegistered(oracle);
        }
    }
}
