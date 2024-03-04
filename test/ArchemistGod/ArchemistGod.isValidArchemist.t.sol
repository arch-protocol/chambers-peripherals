// SPDX-License-Identifier: Apache License 2.0
pragma solidity ^0.8.24;

import { ArchemistGodTest } from "test/utils/ArchemistGodTest.sol";
import { Archemist } from "src/Archemist.sol";

contract IsValidArchemistTest is ArchemistGodTest {
    /*//////////////////////////////////////////////////////////////
                               SUCCESS
    //////////////////////////////////////////////////////////////*/

    /**
     * [SUCCESS] Return True if the Archemist is valid.
     */
    function testIsValidArchemist() public {
        bool isValid = archemistGod.isValidArchemist(address(validArchemist));
        assertEq(isValid, true);
    }

    /**
     * [SUCCESS] Should return False if is not a valid Archemist.
     */
    function testIsNotValidArchemist(address randomAddress) public {
        vm.assume(randomAddress != address(validArchemist));
        bool isValid = archemistGod.isValidArchemist(randomAddress);
        assertEq(isValid, false);
    }

    /**
     * [SUCCESS] Should return False if the Archemist is not valid after creating a new one without the archemistGod.
     */
    function testIsNotValidArchemistAfterCreatingOne() public {
        vm.prank(admin);
        Archemist newArchemist = new Archemist(admin, ADDY, AEDY, ADDY, 1000);
        bool isValid = archemistGod.isValidArchemist(address(newArchemist));
        assertEq(isValid, false);
    }

    /**
     * [SUCCESS] Should return True if the Archemist is not valid after creating a new one with the archemistGod.
     */
    function testIsValidArchemistAfterCreatingOne() public {
        vm.prank(admin);
        Archemist newArchemist = archemistGod.createArchemist(ADDY, AEDY, 1000);
        bool isValid = archemistGod.isValidArchemist(address(newArchemist));
        assertEq(isValid, true);
    }
}
