// SPDX-License-Identifier: Apache License 2.0
pragma solidity ^0.8.24;

import { ArchemistGodTest } from "test/utils/ArchemistGodTest.sol";
import { Archemist } from "src/Archemist.sol";

contract TestGetArchemists is ArchemistGodTest {
    /*//////////////////////////////////////////////////////////////
                               SUCCESS
    //////////////////////////////////////////////////////////////*/

    /**
     * [SUCCESS] Should Return the array of archemists
     */
    function testGetCurrentArchemistsArray() public {
        address[] memory archemistsArray = new address[](1);
        archemistsArray[0] = address(validArchemist);
        address[] memory archemists = archemistGod.getArchemists();
        assertEq(archemists, archemistsArray);
    }

    /**
     * [SUCCESS] Should return Return the array of archemists after creating a new one.
     */
    function testGetCurrentArchemistsArrayAfterCreatingOneWithFactory() public {
        address[] memory archemistsArray = new address[](2);
        archemistsArray[0] = address(validArchemist);
        vm.prank(admin);
        Archemist newArchemist = archemistGod.createArchemist(ADDY, AEDY, 1000);
        archemistsArray[1] = address(newArchemist);
        address[] memory archemists = archemistGod.getArchemists();
        assertEq(archemists, archemistsArray);
    }

    /**
     * [SUCCESS] Should return Return the array of archemists with one element when creating an archemist without the factory.
     */
    function testGetCurrentArchemistsArrayAfterCreatingOneWithoutFactory() public {
        address[] memory archemistsArray = new address[](1);
        archemistsArray[0] = address(validArchemist);
        vm.prank(admin);
        new Archemist(admin, ADDY, AEDY, AEDY, 1000);
        address[] memory archemists = archemistGod.getArchemists();
        assertEq(archemistsArray, archemists);
    }
}
