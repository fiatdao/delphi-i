// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import {CollybusSpotPriceRelayer} from "src/relayer/CollybusSpotPrice/CollybusSpotPriceRelayer.sol";

interface IFactoryCollybusSpotPriceRelayer{
    function create(address collybus_) external returns(address);
}

contract FactoryCollybusSpotPriceRelayer is IFactoryCollybusSpotPriceRelayer{
    function create(address collybus_ ) public override(IFactoryCollybusSpotPriceRelayer) returns(address){
        CollybusSpotPriceRelayer spotPriceRelayer = new CollybusSpotPriceRelayer(
            collybus_
        );
        spotPriceRelayer.allowCaller(keccak256("ANY_SIG"),msg.sender);
        return address(spotPriceRelayer);
    }
}