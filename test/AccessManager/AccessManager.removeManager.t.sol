// SPDX-License-Identifier: Apache License 2.0
pragma solidity ^0.8.20;

import { AccessManager } from "src/AccessManager.sol";
import { IAccessManager } from "src/interfaces/IAccessManager.sol";
import { IAccessControl } from "@openzeppelin/contracts/access/IAccessControl.sol";
import { Test } from "forge-std/Test.sol";

contract RemoveManagerTest is Test {
    /*//////////////////////////////////////////////////////////////
                               VARIABLES
    //////////////////////////////////////////////////////////////*/

    AccessManager public accessManager;
    address public owner = vm.addr(0x1);

    function setUp() public {
        vm.prank(owner);
        accessManager = new AccessManager(owner);
    }

    /*//////////////////////////////////////////////////////////////
                              REVERT
    //////////////////////////////////////////////////////////////*/

    /**
     * [ERROR] Should revert when trying to remove a manager not as an admin
     */
    function testCannotRemoveManagerNotAdmin(address randomCaller, address randomAddress) public {
        vm.assume(randomCaller != owner);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                randomCaller,
                accessManager.DEFAULT_ADMIN_ROLE()
            )
        );
        vm.prank(randomCaller);
        accessManager.removeManager(randomAddress);
    }

    /**
     * [ERROR] Should revert when trying to remove a manager not added
     */
    function testCannotRemoveManagerNotAdded(address randomAddress) public {
        vm.expectRevert(
            abi.encodeWithSelector(IAccessManager.ManagerNotAdded.selector, randomAddress)
        );
        vm.prank(owner);
        accessManager.removeManager(randomAddress);
    }

    /*//////////////////////////////////////////////////////////////
                              SUCCESS
    //////////////////////////////////////////////////////////////*/

    /**
     * [SUCCESS] Should remove a manager as an admin
     */
    function testRemoveManager(address randomAddress) public {
        vm.prank(owner);
        accessManager.addManager(randomAddress);
        vm.prank(owner);
        accessManager.removeManager(randomAddress);
    }
}
