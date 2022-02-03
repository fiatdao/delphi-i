// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import {AggregatorOracle} from "src/aggregator/AggregatorOracle.sol";

interface IFactoryAggregatorOracle{
    function create() external returns(address);
}

contract FactoryAggregatorOracle is IFactoryAggregatorOracle {
    function create() public override(IFactoryAggregatorOracle) returns(address){
        AggregatorOracle aggOracle = new AggregatorOracle();
        aggOracle.allowCaller(keccak256("ANY_SIG"),msg.sender);
        return address(aggOracle);
    }
}