// SPDX-License-Identifier: Apache License 2.0
pragma solidity ^0.8.20;

import { AccessManager } from "src/AccessManager.sol";
import { Test } from "forge-std/Test.sol";

contract GetAdminsTest is Test {
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
                              SUCCESS
    //////////////////////////////////////////////////////////////*/

    /**
     * [SUCCESS] Should return the admins in the contract
     */
    function testGetAdmins(address randomAddress) public {
        vm.assume(randomAddress != owner);
        vm.prank(owner);
        accessManager.addAdmin(randomAddress);

        address[] memory admins = accessManager.getAdmins();
        assertEq(admins.length, 2);
        assertEq(admins[0], owner);
        assertEq(admins[1], randomAddress);
    }
}
