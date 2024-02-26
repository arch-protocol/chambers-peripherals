// SPDX-License-Identifier: Apache License 2.0
pragma solidity ^0.8.20;

import { IAccessManager } from "./interfaces/IAccessManager.sol";
import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";
import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

contract AccessManager is IAccessManager, AccessControl {
    using EnumerableSet for EnumerableSet.AddressSet;
    /*//////////////////////////////////////////////////////////////
                               STORAGE
    //////////////////////////////////////////////////////////////*/

    bytes32 public constant OPERATOR = keccak256("OPERATOR");
    bytes32 public constant MANAGER = keccak256("MANAGER");

    EnumerableSet.AddressSet private operators;
    EnumerableSet.AddressSet private managers;
    EnumerableSet.AddressSet private admins;

    /*//////////////////////////////////////////////////////////////
                               CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor() AccessControl() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        admins.add(msg.sender);
    }

    /*//////////////////////////////////////////////////////////////
                            ACCESS MODIFIERS
    //////////////////////////////////////////////////////////////*/

    modifier onlyManager() {
        if (!hasRole(DEFAULT_ADMIN_ROLE, msg.sender) && !hasRole(MANAGER, msg.sender)) {
            revert CallerIsNotManager(msg.sender);
        }

        _;
    }

    modifier onlyCallerWithAccess() {
        if (
            !hasRole(DEFAULT_ADMIN_ROLE, msg.sender) && !hasRole(MANAGER, msg.sender)
                && !hasRole(OPERATOR, msg.sender)
        ) {
            revert CallerHasNotAccess(msg.sender);
        }

        _;
    }

    /*//////////////////////////////////////////////////////////////
                             FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function addManager(address manager) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (managers.contains(manager)) revert ManagerAlreadyAdded(manager);
        managers.add(manager);
        _grantRole(MANAGER, manager);
    }

    function removeManager(address manager) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (!managers.contains(manager)) revert ManagerNotAdded(manager);
        managers.remove(manager);
        _revokeRole(MANAGER, manager);
    }

    function addOperator(address operator) external onlyManager {
        if (operators.contains(operator)) revert OperatorAlreadyAdded(operator);
        operators.add(operator);
        _grantRole(OPERATOR, operator);
    }

    function removeOperator(address operator) external onlyManager {
        if (!operators.contains(operator)) revert OperatorNotAdded(operator);
        operators.remove(operator);
        _revokeRole(OPERATOR, operator);
    }

    function addAdmin(address admin) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (admins.contains(admin)) revert AdminAlreadyAdded(admin);
        admins.add(admin);
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
    }

    function removeAdmin(address admin) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (!admins.contains(admin)) revert AdminNotAdded(admin);
        admins.remove(admin);
        _revokeRole(DEFAULT_ADMIN_ROLE, admin);
    }

    function getManagers() external view returns (address[] memory) {
        return managers.values();
    }

    function getOperators() external view returns (address[] memory) {
        return operators.values();
    }

    function getAdmins() external view returns (address[] memory) {
        return admins.values();
    }
}
