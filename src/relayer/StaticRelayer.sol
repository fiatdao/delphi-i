// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import {ICollybus} from "src/relayer/ICollybus.sol";
import {IRelayer} from "src/relayer/IRelayer.sol";
import {Guarded} from "src/guarded/Guarded.sol";

contract StaticRelayer is Guarded {
    /// ======== Events ======== ///

    event UpdatedCollybus(
        bytes32 tokenId,
        uint256 rate,
        IRelayer.RelayerType relayerType
    );

    /// ======== Storage ======== ///

    address public immutable collybus;
    IRelayer.RelayerType public immutable relayerType;
    bytes32 public immutable encodedTokenId;
    uint256 public immutable value;

    constructor(
        address collybusAddress_,
        IRelayer.RelayerType type_,
        bytes32 encodedTokenId_,
        uint256 value_
    ) {
        collybus = collybusAddress_;
        relayerType = type_;
        encodedTokenId = encodedTokenId_;
        value = value_;
    }

    /// @notice Pushes the hardcoded value to Collybus for the hardcoded token id
    ///         After the rate is pushed the contract self-destructs
    function execute() public checkCaller {
        if (relayerType == IRelayer.RelayerType.DiscountRate) {
            ICollybus(collybus).updateDiscountRate(
                uint256(encodedTokenId),
                value
            );
        } else if (relayerType == IRelayer.RelayerType.SpotPrice) {
            ICollybus(collybus).updateSpot(
                address(uint160(uint256(encodedTokenId))),
                value
            );
        }

        emit UpdatedCollybus(encodedTokenId, value, relayerType);

        selfdestruct(payable(0));
    }
}
