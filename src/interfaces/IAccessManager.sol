// SPDX-License-Identifier: Apache License 2.0
pragma solidity ^0.8.20;

interface IAccessManager {
    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    error CallerIsNotManager(address caller);

    error CallerHasNotAccess(address caller);

    error ManagerAlreadyAdded(address manager);

    error ManagerNotAdded(address manager);

    error OperatorAlreadyAdded(address operator);

    error OperatorNotAdded(address operator);

    error AdminAlreadyAdded(address admin);

    error AdminNotAdded(address admin);

    /*//////////////////////////////////////////////////////////////
                             FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function addManager(address manager) external;

    function removeManager(address manager) external;

    function addOperator(address operator) external;

    function removeOperator(address operator) external;

    function addAdmin(address admin) external;

    function removeAdmin(address admin) external;

    function getManagers() external view returns (address[] memory);

    function getOperators() external view returns (address[] memory);

    function getAdmins() external view returns (address[] memory);
}
