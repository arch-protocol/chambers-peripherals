// SPDX-License-Identifier: Apache License 2.0
pragma solidity ^0.8.20;

import { Archemist } from "src/Archemist.sol";
import { IAccessManager } from "src/interfaces/IAccessManager.sol";
import { IArchemist } from "src/interfaces/IArchemist.sol";
import { Test } from "forge-std/Test.sol";

contract ArchemistsUpdatePricePerShareTest is Test {
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
     * [ERROR] Should revert when trying to update the price per share not as admin
     */
    function testCannotUpdatePricePerShareNotAdmin(address randomCaller, uint256 randomUint)
        public
    {
        vm.assume(randomUint != 0);
        vm.assume(randomCaller != admin);
        vm.expectRevert(
            abi.encodeWithSelector(IAccessManager.CallerHasNoAccess.selector, randomCaller)
        );
        vm.prank(randomCaller);
        archemist.updatePricePerShare(randomUint);
        assertEq(archemist.paused(), true);
    }

    /**
     * [ERROR] Should revert when trying to update the price per share when not admin nor manager
     */
    function testCannotUpdatePricePerShareNotAdminNorManager(
        address randomCaller,
        uint256 randomUint,
        address manager
    ) public {
        vm.assume(randomUint != 0);
        vm.assume(randomCaller != admin);
        vm.assume(randomCaller != manager);

        vm.prank(admin);
        archemist.addManager(manager);

        vm.expectRevert(
            abi.encodeWithSelector(IAccessManager.CallerHasNoAccess.selector, randomCaller)
        );

        vm.prank(randomCaller);
        archemist.updatePricePerShare(randomUint);
        assertEq(archemist.paused(), true);
    }

    /**
     * [ERROR] Should revert when trying to update the price per share when not admin, manager nor operator
     */
    function testCannotUpdatePricePerShareNotAdminNorManagerNorOperator(
        address randomCaller,
        uint256 randomUint,
        address manager,
        address operator
    ) public {
        vm.assume(randomUint != 0);
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
        archemist.updatePricePerShare(randomUint);
        assertEq(archemist.paused(), true);
    }

    /**
     * [ERROR] Should revert when trying to update the price per share with a price of 0
     */
    function testCannotUpdatePricePerShareZeroPrice() public {
        vm.prank(admin);
        vm.expectRevert(abi.encodeWithSelector(IArchemist.ZeroPricePerShare.selector));
        archemist.updatePricePerShare(0);
        assertEq(archemist.paused(), true);
    }

    /*//////////////////////////////////////////////////////////////
                              SUCCESS
    //////////////////////////////////////////////////////////////*/

    /**
     * [SUCCESS] Should update the price per share when called by admin
     */
    function testUpdatePricePerShareAsAdmin(uint256 randomUint) public {
        vm.assume(randomUint != 0);
        vm.prank(admin);
        archemist.updatePricePerShare(randomUint);

        assertEq(archemist.pricePerShare(), randomUint);
        assertEq(archemist.paused(), true);
    }

    /**
     * [SUCCESS] Should update the price per share when called by manager
     */
    function testUpdatePricePerShareAsManager(uint256 randomUint, address manager) public {
        vm.assume(randomUint != 0);
        vm.prank(admin);
        archemist.addManager(manager);
        vm.prank(manager);
        archemist.updatePricePerShare(randomUint);

        assertEq(archemist.pricePerShare(), randomUint);
        assertEq(archemist.paused(), true);
    }

    /**
     * [SUCCESS] Should update the price per share when called by operator
     */
    function testUpdatePricePerShareAsOperator(uint256 randomUint, address operator) public {
        vm.assume(randomUint != 0);
        vm.prank(admin);
        archemist.addOperator(operator);
        vm.prank(operator);
        archemist.updatePricePerShare(randomUint);

        assertEq(archemist.pricePerShare(), randomUint);
        assertEq(archemist.paused(), true);
    }
}
