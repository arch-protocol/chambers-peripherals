// SPDX-License-Identifier: Apache License 2.0
pragma solidity ^0.8.20;

import { AccessManager } from "src/AccessManager.sol";
import { IAccessManager } from "src/interfaces/IAccessManager.sol";
import { IAccessControl } from "@openzeppelin/contracts/access/IAccessControl.sol";
import { Test } from "forge-std/Test.sol";

contract RemoveAdminTest is Test {
    /*//////////////////////////////////////////////////////////////
                               VARIABLES
    //////////////////////////////////////////////////////////////*/

    AccessManager public accessManager;
    address public owner = vm.addr(0x1);

    function setUp() public {
        vm.prank(owner);
        accessManager = new AccessManager();
    }

    /*//////////////////////////////////////////////////////////////
                              REVERT
    //////////////////////////////////////////////////////////////*/

    /**
     * [ERROR] Should revert when trying to remove an admin not as another admin
     */
    function testCannotRemoveAdminNotAdmin(address randomCaller, address randomAddress) public {
        vm.assume(randomCaller != owner);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                randomCaller,
                accessManager.DEFAULT_ADMIN_ROLE()
            )
        );
        vm.prank(randomCaller);
        accessManager.removeAdmin(randomAddress);
    }

    /**
     * [ERROR] Should revert when trying to remove an admin not added
     */
    function testCannotRemoveAdminNotAdded(address randomAddress) public {
        vm.assume(randomAddress != owner);
        vm.expectRevert(
            abi.encodeWithSelector(IAccessManager.AdminNotAdded.selector, randomAddress)
        );
        vm.prank(owner);
        accessManager.removeAdmin(randomAddress);
    }

    /*//////////////////////////////////////////////////////////////
                              SUCCESS
    //////////////////////////////////////////////////////////////*/

    /**
     * [SUCCESS] Should remove an admin as another admin
     */
    function testRemoveAdmin(address randomAddress) public {
        vm.assume(randomAddress != owner);
        vm.prank(owner);
        accessManager.addAdmin(randomAddress);
        vm.prank(owner);
        accessManager.removeAdmin(randomAddress);
    }
}
