// SPDX-License-Identifier: Apache License 2.0
pragma solidity ^0.8.20;

import { AccessManager } from "src/AccessManager.sol";
import { Test } from "forge-std/Test.sol";

contract GetManagersTest is Test {
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
     * [SUCCESS] Should return the managers in the contract
     */
    function testGetManagers(address randomAddress) public {
        vm.prank(owner);
        accessManager.addManager(randomAddress);

        address[] memory managers = accessManager.getManagers();
        assertEq(managers.length, 1);
        assertEq(managers[0], randomAddress);
    }
}
