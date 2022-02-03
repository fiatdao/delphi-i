// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import {CollybusDiscountRateRelayer} from "src/relayer/CollybusDiscountRate/CollybusDiscountRateRelayer.sol";

interface IFactoryCollybusDiscountRateRelayer{
    function create(address collybus_) external returns(address);
}

contract FactoryCollybusDiscountRateRelayer is IFactoryCollybusDiscountRateRelayer{
    function create(address collybus_ ) public override(IFactoryCollybusDiscountRateRelayer) returns(address){
        CollybusDiscountRateRelayer discountRateRelayer = new CollybusDiscountRateRelayer(
            collybus_
        );

        discountRateRelayer.allowCaller(keccak256("ANY_SIG"),msg.sender);

        return address(discountRateRelayer);
    }
}