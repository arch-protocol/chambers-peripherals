// SPDX-License-Identifier: Apache License 2.0
pragma solidity ^0.8.24;

import { ArchemistTest } from "test/utils/ArchemistTest.sol";
import { IArchemist } from "src/interfaces/IArchemist.sol";
import { IAccessManager } from "src/interfaces/IAccessManager.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract ArchemistTransferErc20PartialBalance is ArchemistTest {
    /*//////////////////////////////////////////////////////////////
                              REVERT
    //////////////////////////////////////////////////////////////*/

    /**
     * [ERROR] Should revert when trying to transfer erc20 if not admin.
     */
    function testCannotTransferErc20PartialBalanceNotAdmin(
        address randomCaller, 
        address tokenToWithdraw, 
        uint256 amount
    ) public {
        vm.assume(amount != 0);
        vm.assume(randomCaller != admin);
        vm.expectRevert(
            abi.encodeWithSelector(IAccessManager.CallerIsNotManager.selector, randomCaller)
        );
        vm.prank(randomCaller);
        archemist.transferErc20PartialBalance(tokenToWithdraw, amount);
        assertEq(archemist.paused(), true);
    }

    /**
     * [ERROR] Should revert when trying to transfer erc20 if not admin nor manager.
     */
    function testCannotTransferErc20PartialBalanceWhenNotAdminNorManager(
        address randomCaller,
        address manager,
        address tokenToWithdraw,
        uint256 amount
    ) public {
        vm.assume(amount != 0);
        vm.assume(randomCaller != admin);
        vm.assume(randomCaller != manager);

        vm.prank(admin);
        archemist.addManager(manager);

        vm.expectRevert(
            abi.encodeWithSelector(IAccessManager.CallerIsNotManager.selector, randomCaller)
        );

        vm.prank(randomCaller);
        archemist.transferErc20PartialBalance(tokenToWithdraw, amount);
        assertEq(archemist.paused(), true);
    }

    /**
     * [ERROR] Should revert when trying to transfer erc20 if not admin nor manager nor operator.
     */
    function testCannotTransferErc20PartialBalanceAsOperator(
        address manager,
        address operator,
        address tokenToWithdraw,
        uint256 amount
    ) public {
        vm.assume(amount != 0);
        vm.assume(operator != admin);
        vm.assume(operator != manager);

        vm.startPrank(admin);
        archemist.addManager(manager);
        archemist.addOperator(operator);
        vm.stopPrank();

        vm.expectRevert(
            abi.encodeWithSelector(IAccessManager.CallerIsNotManager.selector, operator)
        );

        vm.prank(operator);
        archemist.transferErc20PartialBalance(tokenToWithdraw, amount);
        assertEq(archemist.paused(), true);
    }

    /**
     * [ERROR] Should revert when trying to withdraw an amount greater than current balance.
     */
    function testCannotTransferErc20PartialBalanceWhenNotEnoughBalance(
        address manager,
        address operator,
        uint256 amount
    ) public {
        vm.assume(amount != 0);
        vm.assume(operator != admin);
        vm.assume(operator != manager);

        vm.startPrank(admin);
        archemist.addManager(manager);
        archemist.addOperator(operator);
        vm.stopPrank();

        vm.expectRevert(
            abi.encodeWithSelector(IArchemist.InsufficientTokenBalance.selector)
        );

        vm.prank(manager);
        archemist.transferErc20PartialBalance(AEDY, amount);
        assertEq(archemist.paused(), true);
    }

 

    /*//////////////////////////////////////////////////////////////
                              SUCCESS
    //////////////////////////////////////////////////////////////*/

    /**
     * [SUCCESS] Should transfer erc20 tokens when called by admin.
     */
    function testTransferErc20PartialBalanceAsAdmin(uint128 randomUint) public {
        vm.assume(randomUint != 0);

        deal(AEDY, address(archemist), randomUint);

        vm.prank(admin);
        archemist.transferErc20PartialBalance(AEDY, randomUint);

        assertEq(IERC20(AEDY).balanceOf(address(archemist)), 0);
        assertEq(IERC20(AEDY).balanceOf(admin), randomUint);
        assertEq(archemist.paused(), true);
    }

    /**
     * [SUCCESS] Should transfer erc20 tokens to the manager when called by manager.
     */
    function testTransferErc20PartialBalanceAsManager(uint128 randomUint, address manager) public {
        vm.assume(manager != address(0x0));
        vm.assume(randomUint != 0);

        deal(AEDY, address(archemist), randomUint);

        vm.prank(admin);
        archemist.addManager(manager);

        vm.prank(manager);
        archemist.transferErc20PartialBalance(AEDY, randomUint);

        assertEq(IERC20(AEDY).balanceOf(address(archemist)), 0);
        assertEq(IERC20(AEDY).balanceOf(manager), randomUint);
        assertEq(archemist.paused(), true);
    }
}
