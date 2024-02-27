// SPDX-License-Identifier: Apache License 2.0
pragma solidity ^0.8.24;

import { Archemist } from "src/Archemist.sol";
import { ArchemistTest } from "test/utils/ArchemistTest.sol";
import { IAccessManager } from "src/interfaces/IAccessManager.sol";
import { Test } from "forge-std/Test.sol";
import { Pausable } from "@openzeppelin/contracts/utils/Pausable.sol";

contract ArchemistPauseTest is ArchemistTest {

    /*//////////////////////////////////////////////////////////////
                              REVERT
    //////////////////////////////////////////////////////////////*/

    /**
     * [ERROR] Should revert when trying to pause the contract without access
     */
    function testCannotPauseNoAccess(address randomCaller) public {
        vm.assume(randomCaller != admin);

        vm.prank(admin);
        archemist.unpause();

        vm.expectRevert(
            abi.encodeWithSelector(IAccessManager.CallerHasNoAccess.selector, randomCaller)
        );
        vm.prank(randomCaller);
        archemist.pause();
        assertEq(archemist.paused(), false);
    }

    /**
     * [ERROR] Should revert when trying to pause the contract when not admin nor manager.
     */
    function testCannotPauseNotAdminNorManager(address randomCaller, address manager) public {
        vm.assume(randomCaller != admin);
        vm.assume(randomCaller != manager);

        

        vm.startPrank(admin);
        archemist.unpause();
        archemist.addManager(manager);
        vm.stopPrank();

        vm.expectRevert(
            abi.encodeWithSelector(IAccessManager.CallerHasNoAccess.selector, randomCaller)
        );

        vm.prank(randomCaller);
        archemist.pause();
        assertEq(archemist.paused(), false);
    }

    /**
     * [ERROR] Should revert when trying to pause the contract when not admin, manager nor operator.
     */
    function testCannotPauseNotAdminNorManagerNorOperator(
        address randomCaller,
        address manager,
        address operator
    ) public {
        vm.assume(randomCaller != admin);
        vm.assume(randomCaller != manager);
        vm.assume(randomCaller != operator);

        vm.startPrank(admin);
        archemist.unpause();
        archemist.addManager(manager);
        archemist.addOperator(operator);
        vm.stopPrank();

        vm.expectRevert(
            abi.encodeWithSelector(IAccessManager.CallerHasNoAccess.selector, randomCaller)
        );

        vm.prank(randomCaller);
        archemist.pause();
        assertEq(archemist.paused(), false);
    }

    /**
     * [ERROR] Should revert when trying to pause the contract when already paused.
     */
    function testCannotPauseAlreadyPaused(uint256 randomUint) public {
        vm.assume(randomUint != 0);

        vm.expectRevert(abi.encodeWithSelector(Pausable.EnforcedPause.selector));

        vm.prank(admin);
        archemist.pause();
    }

    /*//////////////////////////////////////////////////////////////
                              SUCCESS
    //////////////////////////////////////////////////////////////*/

    /**
     * [SUCCESS] Should pause the contract when called by admin
     */
    function testPauseAsAdmin(uint256 randomUint) public {
        vm.assume(randomUint != 0);

        vm.prank(admin);
        archemist.unpause();

        vm.prank(admin);
        archemist.pause();

        assertEq(archemist.paused(), true);
    }

    /**
     * [SUCCESS] Should pause the contract when called by manager
     */
    function testPauseAsManager(uint256 randomUint, address manager) public {
        vm.assume(randomUint != 0);

        vm.startPrank(admin);
        archemist.unpause();
        archemist.addManager(manager);
        vm.stopPrank();

        vm.prank(manager);
        archemist.pause();

        assertEq(archemist.paused(), true);
    }

    /**
     * [SUCCESS] Should pause the contract when called by operator
     */
    function testPauseAsOperator(uint256 randomUint, address operator) public {
        vm.assume(randomUint != 0);

        vm.startPrank(admin);
        archemist.unpause();
        archemist.addOperator(operator);
        vm.stopPrank();

        vm.prank(operator);
        archemist.pause();

        assertEq(archemist.paused(), true);
    }
}
