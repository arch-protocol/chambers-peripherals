// SPDX-License-Identifier: Apache License 2.0
pragma solidity ^0.8.24;

import { ArchemistGodTest } from "test/utils/ArchemistGodTest.sol";
import { IAccessManager } from "src/interfaces/IAccessManager.sol";

contract CreateArchemistTest is ArchemistGodTest {
    /*//////////////////////////////////////////////////////////////
                               REVERT
    //////////////////////////////////////////////////////////////*/

    /**
     * [REVERT] Should revert if the caller is not an admin, manager, or operator.
     */
    function testCreateArchemistAsRandom(address randomAddress) public {
        vm.assume(randomAddress != admin);
        vm.expectRevert(
            abi.encodeWithSelector(IAccessManager.CallerHasNoAccess.selector, randomAddress)
        );
        vm.prank(randomAddress);
        archemistGod.createArchemist(ADDY, AEDY, 1000);
    }

    /*//////////////////////////////////////////////////////////////
                               SUCCESS
    //////////////////////////////////////////////////////////////*/

    /**
     * [SUCCESS] Should create an Archemist as admin.
     */
    function testCreateArchemistAsAdmin(uint24 exchangeFee) public {
        vm.prank(admin);
        archemistGod.createArchemist(ADDY, AEDY, exchangeFee);
    }

    /**
     * [SUCCESS] Should create an Archemist as a manager.
     */
    function testCreateArchemistAsManager(uint24 exchangeFee, address manager) public {
        vm.assume(manager != admin);
        vm.prank(admin);
        archemistGod.addManager(manager);

        vm.prank(manager);
        archemistGod.createArchemist(ADDY, AEDY, exchangeFee);
    }

    /**
     * [SUCCESS] Should create an Archemist as an operator.
     */
    function testCreateArchemistAsOperator(uint24 exchangeFee, address operator) public {
        vm.assume(operator != admin);
        vm.prank(admin);
        archemistGod.addOperator(operator);

        vm.prank(operator);
        archemistGod.createArchemist(ADDY, AEDY, exchangeFee);
    }
}
