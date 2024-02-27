// SPDX-License-Identifier: Apache License 2.0
pragma solidity ^0.8.24;

import { Archemist } from "src/Archemist.sol";
import { IAccessManager } from "src/interfaces/IAccessManager.sol";
import { Test } from "forge-std/Test.sol";
import { Pausable } from "@openzeppelin/contracts/utils/Pausable.sol";

contract ArchemistUnpause is Test {
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
        vm.prank(admin);
        archemist = new Archemist(exchangeToken, baseTokenAddress, archemistGod, exchangeFee);
    }

    /*//////////////////////////////////////////////////////////////
                              REVERT
    //////////////////////////////////////////////////////////////*/

    /**
     * [ERROR] Should revert when trying to unpause the contract as admin.
     */
    function testCannotUnpauseNotAdmin(address randomCaller) public {
        vm.assume(randomCaller != admin);
        vm.expectRevert(
            abi.encodeWithSelector(IAccessManager.CallerHasNoAccess.selector, randomCaller)
        );
        vm.prank(randomCaller);
        archemist.unpause();
        assertEq(archemist.paused(), true);
    }

    /**
     * [ERROR] Should revert when trying to unpause the contract when not admin nor manager.
     */
    function testCannotUnpauseotAdminNorManager(address randomCaller, address manager) public {
        vm.assume(randomCaller != admin);
        vm.assume(randomCaller != manager);

        vm.prank(admin);
        archemist.addManager(manager);

        vm.expectRevert(
            abi.encodeWithSelector(IAccessManager.CallerHasNoAccess.selector, randomCaller)
        );

        vm.prank(randomCaller);
        archemist.unpause();
        assertEq(archemist.paused(), true);
    }

    /**
     * [ERROR] Should revert when trying to unpause the contract when not admin, manager nor operator.
     */
    function testCannotUnpauseNotAdminNorManagerNorOperator(
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
        archemist.unpause();
        assertEq(archemist.paused(), true);
    }

    /**
     * [ERROR] Should revert when trying to unpause the contract when not paused.
     */
    function testCannotUnpauseNotPaused() public {
        vm.prank(admin);
        archemist.unpause();

        vm.expectRevert(abi.encodeWithSelector(Pausable.ExpectedPause.selector));

        vm.prank(admin);
        archemist.unpause();
    }

    /*//////////////////////////////////////////////////////////////
                              SUCCESS
    //////////////////////////////////////////////////////////////*/

    /**
     * [SUCCESS] Should unpause the contract when called by admin
     */
    function testUnpauseAsAdmin(uint256 randomUint) public {
        vm.assume(randomUint != 0);
        vm.prank(admin);
        archemist.unpause();

        assertEq(archemist.paused(), false);
    }

    /**
     * [SUCCESS] Should unpause the contract when called by manager
     */
    function testUnpauseAsManager(uint256 randomUint, address manager) public {
        vm.assume(randomUint != 0);
        vm.prank(admin);
        archemist.addManager(manager);
        vm.prank(manager);
        archemist.unpause();

        assertEq(archemist.paused(), false);
    }

    /**
     * [SUCCESS] Should unpause the contract when called by operator
     */
    function testUnpauseAsOperator(uint256 randomUint, address operator) public {
        vm.assume(randomUint != 0);
        vm.prank(admin);
        archemist.addOperator(operator);
        vm.prank(operator);
        archemist.unpause();

        assertEq(archemist.paused(), false);
    }
}
