// SPDX-License-Identifier: Apache License 2.0
pragma solidity ^0.8.20;

import { Archemist } from "src/Archemist.sol";
import { IAccessManager } from "src/interfaces/IAccessManager.sol";
import { Test } from "forge-std/Test.sol";

contract ArchemistPause is Test {
    /*//////////////////////////////////////////////////////////////
                               VARIABLES
    //////////////////////////////////////////////////////////////*/

    Archemist public archemist;

    address public admin = vm.addr(0x1);
    address public exchangeToken = vm.addr(0x2);
    address public baseTokenAddress = vm.addr(0x3);
    address public archemistGod = vm.addr(0x4);

    uint24 public exchangeFee = 1000;

    function setUp() public {
        vm.startPrank(admin);
        archemist = new Archemist(exchangeToken, baseTokenAddress, archemistGod, exchangeFee);
        archemist.unpause();
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                              REVERT
    //////////////////////////////////////////////////////////////*/

    /**
     * [ERROR] Should revert when trying to pause the contract as admin.
     */
    function testCannotPauseNotAdmin(address randomCaller)
        public
    {
        vm.assume(randomCaller != admin);
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
    function testCannotPauseotAdminNorManager(
        address randomCaller,
        address manager
    ) public {
        vm.assume(randomCaller != admin);
        vm.assume(randomCaller != manager);

        vm.prank(admin);
        archemist.addManager(manager);

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

    /*//////////////////////////////////////////////////////////////
                              SUCCESS
    //////////////////////////////////////////////////////////////*/

    /**
     * [SUCCESS] Should pause the contract when called by admin
     */
    function testPauseAsAdmin(uint256 randomUint) public {
        vm.assume(randomUint != 0);
        vm.prank(admin);
        archemist.pause();

        assertEq(archemist.paused(), true);
    }

    /**
     * [SUCCESS] Should pause the contract when called by manager
     */
    function testPauseAsManager(uint256 randomUint, address manager) public {
        vm.assume(randomUint != 0);
        vm.prank(admin);
        archemist.addManager(manager);
        vm.prank(manager);
        archemist.pause();

        assertEq(archemist.paused(), true);
    }

    /**
     * [SUCCESS] Should pause the contract when called by operator
     */
    function testPauseAsOperator(uint256 randomUint, address operator) public {
        vm.assume(randomUint != 0);
        vm.prank(admin);
        archemist.addOperator(operator);
        vm.prank(operator);
        archemist.pause();

        assertEq(archemist.paused(), true);
    }
}
