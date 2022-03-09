// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import {Hevm} from "../test/utils/Hevm.sol";
import {DSTest} from "lib/ds-test/src/test.sol";
import {Caller} from "../test/utils/Caller.sol";

import {ICollybus} from "./ICollybus.sol";
import {IRelayer} from "./IRelayer.sol";

import {StaticRelayer} from "./StaticRelayer.sol";

contract TestCollybus is ICollybus {
    mapping(uint256 => uint256) public discountRateForToken;
    mapping(address => uint256) public spotPriceForToken;

    function updateDiscountRate(uint256 tokenId, uint256 rate)
        external
        override(ICollybus)
    {
        discountRateForToken[tokenId] = rate;
    }

    function updateSpot(address tokenAddress, uint256 spot)
        external
        override(ICollybus)
    {
        spotPriceForToken[tokenAddress] = spot;
    }
}

contract StaticRelayerTest is DSTest {
    Hevm internal hevm = Hevm(DSTest.HEVM_ADDRESS);

    TestCollybus internal collybus;

    function setUp() public {
        collybus = new TestCollybus();
    }

    function test_deploy() public {
        StaticRelayer staticRelayer = new StaticRelayer(
            address(collybus),
            IRelayer.RelayerType.DiscountRate,
            bytes32(uint256(1)),
            1e18
        );

        assertTrue(
            address(staticRelayer) != address(0),
            "StaticRelayer should be deployed"
        );
    }

    function test_execute_updates_DiscountRateInCollybus() public {
        // Create the static relayer with a tokenId and a value
        uint256 tokenId = 1;
        StaticRelayer staticRelayer = new StaticRelayer(
            address(collybus),
            IRelayer.RelayerType.DiscountRate,
            bytes32(tokenId),
            1e18
        );

        // Push the value to Collybus
        staticRelayer.execute();

        assertTrue(
            collybus.discountRateForToken(tokenId) == 1e18,
            "Invalid discount rate in Collybus"
        );
    }

    function test_execute_updates_SpotPriceInCollybus() public {
        // Create the static relayer with a tokenId and a value
        address tokenAddress = address(0x1234);
        StaticRelayer staticRelayer = new StaticRelayer(
            address(collybus),
            IRelayer.RelayerType.SpotPrice,
            bytes32(uint256(uint160(tokenAddress))),
            1e18
        );

        // Push the value to Collybus
        staticRelayer.execute();

        assertTrue(
            collybus.spotPriceForToken(tokenAddress) == 1e18,
            "Invalid spot price in Collybus"
        );
    }

    function test_execute_OnlyAuthorizedUsers() public {
        Caller user = new Caller();

        // Create the static relayer with a tokenId and a value
        bytes32 encodedTokenId = bytes32(uint256(1));
        StaticRelayer staticRelayer = new StaticRelayer(
            address(collybus),
            IRelayer.RelayerType.DiscountRate,
            encodedTokenId,
            1e18
        );

        // Call execute from an unauthorized address
        (bool ok, ) = user.externalCall(
            address(staticRelayer),
            abi.encodeWithSelector(StaticRelayer.execute.selector)
        );

        assertTrue(
            ok == false,
            "Only authorized users should be able to call execute()"
        );
    }
}
