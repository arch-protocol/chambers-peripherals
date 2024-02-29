// SPDX-License-Identifier: Apache License 2.0
pragma solidity ^0.8.20;

import { AccessManager } from "src/AccessManager.sol";
import { IAccessManager } from "src/interfaces/IAccessManager.sol";
import { IAccessControl } from "@openzeppelin/contracts/access/IAccessControl.sol";
import { Test } from "forge-std/Test.sol";

contract AddAdminTest is Test {
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
     * [ERROR] Should revert when trying to add an admin not as another admin
     */
    function testCannotAddAdminNotAdmin(address randomCaller, address randomAddress) public {
        vm.assume(randomCaller != owner);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                randomCaller,
                accessManager.DEFAULT_ADMIN_ROLE()
            )
        );
        vm.prank(randomCaller);
        accessManager.addAdmin(randomAddress);
    }

    /**
     * [ERROR] Should revert when trying to add an admin already added
     */
    function testCannotAddAdminAlreadyAdded(address randomAddress) public {
        vm.assume(randomAddress != owner);
        vm.startPrank(owner);
        accessManager.addAdmin(randomAddress);
        vm.expectRevert(
            abi.encodeWithSelector(IAccessManager.AdminAlreadyAdded.selector, randomAddress)
        );
        accessManager.addAdmin(randomAddress);
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                              SUCCESS
    //////////////////////////////////////////////////////////////*/

    /**
     * [SUCCESS] Should add an admin as another admin
     */
    function testAddAdmin(address randomAddress) public {
        vm.assume(randomAddress != owner);
        vm.prank(owner);
        accessManager.addAdmin(randomAddress);
    }
}
