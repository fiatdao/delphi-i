// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import {Hevm} from "src/test/utils/Hevm.sol";
import {DSTest} from "lib/ds-test/src/test.sol";
import {Caller} from "src/test/utils/Caller.sol";

import {ICollybus} from "src/relayer/ICollybus.sol";
import {IRelayer} from "src/relayer/IRelayer.sol";

import {StaticRelayer} from "src/relayer/StaticRelayer.sol";

contract TestCollybus is ICollybus {
    mapping(bytes32 => uint256) public valueForToken;

    function updateDiscountRate(uint256 tokenId, uint256 rate)
        external
        override(ICollybus)
    {
        valueForToken[bytes32(uint256(tokenId))] = rate;
    }

    function updateSpot(address tokenAddress, uint256 spot)
        external
        override(ICollybus)
    {
        valueForToken[bytes32(uint256(uint160(tokenAddress)))] = spot;
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
        bytes32 encodedTokenId = bytes32(uint256(1));
        StaticRelayer staticRelayer = new StaticRelayer(
            address(collybus),
            IRelayer.RelayerType.DiscountRate,
            encodedTokenId,
            1e18
        );
        staticRelayer.execute();

        assertTrue(
            collybus.valueForToken(encodedTokenId) == 1e18,
            "Invalid discount rate in Collybus"
        );
    }

    function test_execute_updates_SpotPriceInCollybus() public {
        bytes32 encodedTokenId = bytes32(bytes20(address(0x1234)));
        StaticRelayer staticRelayer = new StaticRelayer(
            address(collybus),
            IRelayer.RelayerType.SpotPrice,
            encodedTokenId,
            1e18
        );
        staticRelayer.execute();

        assertTrue(
            collybus.valueForToken(encodedTokenId) == 1e18,
            "Invalid spot price in Collybus"
        );
    }

    function test_execute_OnlyAuthorizedUsers() public {
        Caller user = new Caller();
        bytes32 encodedTokenId = bytes32(uint256(1));
        StaticRelayer staticRelayer = new StaticRelayer(
            address(collybus),
            IRelayer.RelayerType.DiscountRate,
            encodedTokenId,
            1e18
        );

        // Add the oracle
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
