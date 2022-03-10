// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import {AggregatorOracle} from "../aggregator/AggregatorOracle.sol";

interface IAggregatorOracleFactory {
    function create() external returns (address);
}

contract AggregatorOracleFactory is IAggregatorOracleFactory {
    function create()
        public
        override(IAggregatorOracleFactory)
        returns (address)
    {
        AggregatorOracle aggOracle = new AggregatorOracle();
        aggOracle.allowCaller(aggOracle.ANY_SIG(), msg.sender);
        return address(aggOracle);
    }
}
