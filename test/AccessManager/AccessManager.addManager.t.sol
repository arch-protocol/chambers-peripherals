// SPDX-License-Identifier: Apache License 2.0
pragma solidity ^0.8.20;

import { AccessManager } from "src/AccessManager.sol";
import { IAccessManager } from "src/interfaces/IAccessManager.sol";
import { IAccessControl } from "@openzeppelin/contracts/access/IAccessControl.sol";
import { Test } from "forge-std/Test.sol";

contract AddManagerTest is Test {
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
     * [ERROR] Should revert when trying to add a manager not as an admin
     */
    function testCannotAddManagerNotAdmin(address randomCaller, address randomAddress) public {
        vm.assume(randomCaller != owner);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                randomCaller,
                accessManager.DEFAULT_ADMIN_ROLE()
            )
        );
        vm.prank(randomCaller);
        accessManager.addManager(randomAddress);
    }

    /**
     * [ERROR] Should revert when trying to add a manager already added
     */
    function testCannotAddManagerAlreadyAdded(address randomAddress) public {
        vm.startPrank(owner);
        accessManager.addManager(randomAddress);
        vm.expectRevert(
            abi.encodeWithSelector(IAccessManager.ManagerAlreadyAdded.selector, randomAddress)
        );
        accessManager.addManager(randomAddress);
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                              SUCCESS
    //////////////////////////////////////////////////////////////*/

    /**
     * [SUCCESS] Should add a manager as admin
     */
    function testAddManager(address randomAddress) public {
        vm.prank(owner);
        accessManager.addManager(randomAddress);
    }
}
