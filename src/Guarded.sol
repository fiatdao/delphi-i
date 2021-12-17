// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.0;

abstract contract Guarded {
    bytes32 public constant ROOT_ROLE = keccak256("ROOT_ROLE");

    mapping(bytes32 => mapping(address => bool)) private _roleMembers;

    event GrantRole(bytes32 role, address who);
    event RevokeRole(bytes32 role, address who);

    constructor() {
        // set root role
        _roleMembers[ROOT_ROLE][msg.sender] = true;
        emit GrantRole(ROOT_ROLE, msg.sender);
    }

    modifier onlyRoot() {
        require(hasRole(ROOT_ROLE, msg.sender), "Guarded/not-root");
        _;
    }

    modifier onlyRole(bytes32 role) {
        require(hasRole(role, msg.sender), "Guarded/not-granted");
        _;
    }

    function grantRole(bytes32 role, address who) external onlyRoot {
        _roleMembers[role][who] = true;
        emit GrantRole(role, who);
    }

    function revokeRole(bytes32 role, address who) external onlyRoot {
        _roleMembers[role][who] = false;
        emit RevokeRole(role, who);
    }

    function hasRole(bytes32 role, address who) public view returns (bool) {
        return (_roleMembers[role][who] || _roleMembers[ROOT_ROLE][who]);
    }
}
