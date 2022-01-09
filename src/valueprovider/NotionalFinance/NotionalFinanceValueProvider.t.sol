// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import "ds-test/test.sol";

import "src/test/utils/Caller.sol";
import {Hevm} from "src/test/utils/Hevm.sol";
import {MockProvider} from "src/test/utils/MockProvider.sol";

import {NotionalFinanceValueProvider} from "./NotionalFinanceValueProvider.sol";

contract NotionalFinanceValueProviderTest is DSTest {
    Hevm internal hevm = Hevm(DSTest.HEVM_ADDRESS);

    NotionalFinanceValueProvider internal notionalVP;

    function setUp() public {
        notionalVP = new NotionalFinanceValueProvider();
    }

    function test_deploy() public {
        assertTrue(address(notionalVP) != address(0));
    }
}