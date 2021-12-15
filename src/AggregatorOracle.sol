// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

// @notice Emitted when trying to add an oracle that already exists
error AggregatorOracle__addOracle_oracleAlreadyRegistered(address oracle);

// @notice Emitted when one does not have the right permissions to manage oracles
error AggregatorOracle__notAuthorized();


contract AggregatorOracle {
    using EnumerableSet for EnumerableSet.AddressSet;

    EnumerableSet.AddressSet private oracles;

    function oracleCount() public view returns (uint) {
        return oracles.length();
    }

    function addOracle(address oracle) public {
        bool added = oracles.add(oracle);
        if (added == false) {
            revert AggregatorOracle__addOracle_oracleAlreadyRegistered(oracle);
        }
    }

    function removeOracle(address oracle) public {
        // oracles.
    }
}