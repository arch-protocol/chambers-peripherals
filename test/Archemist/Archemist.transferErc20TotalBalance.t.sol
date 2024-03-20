// SPDX-License-Identifier: Apache License 2.0
pragma solidity ^0.8.24;

import { ArchemistTest } from "test/utils/ArchemistTest.sol";
import { IArchemist } from "src/interfaces/IArchemist.sol";
import { IAccessManager } from "src/interfaces/IAccessManager.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract ArchemistTransferErc20 is ArchemistTest {
    /*//////////////////////////////////////////////////////////////
                              REVERT
    //////////////////////////////////////////////////////////////*/

    /**
     * [ERROR] Should revert when trying to transfer all erc20 token balance if not admin.
     */
    function testCannotTransferErc20TotalBalanceNotAdmin(address randomCaller, address tokenToWithdraw)
        public
    {
        vm.assume(randomCaller != admin);
        vm.expectRevert(
            abi.encodeWithSelector(IAccessManager.CallerIsNotManager.selector, randomCaller)
        );
        vm.prank(randomCaller);
        archemist.transferErc20TotalBalance(tokenToWithdraw);
        assertEq(archemist.paused(), true);
    }

    /**
     * [ERROR] Should revert when trying to transfer all erc20 token balance if not admin nor manager.
     */
    function testCannotTransferErc20TotalBalanceNotAdminNorManager(
        address randomCaller,
        address manager,
        address tokenToWithdraw
    ) public {
        vm.assume(randomCaller != admin);
        vm.assume(randomCaller != manager);

        vm.prank(admin);
        archemist.addManager(manager);

        vm.expectRevert(
            abi.encodeWithSelector(IAccessManager.CallerIsNotManager.selector, randomCaller)
        );

        vm.prank(randomCaller);
        archemist.transferErc20TotalBalance(tokenToWithdraw);
        assertEq(archemist.paused(), true);
    }

    /**
     * [ERROR] Should revert when trying to transfer erc20  if not admin nor manager nor operator.
     */
    function testCannotTransferErc20TotalBalanceAsOperator(
        address manager,
        address operator,
        address tokenToWithdraw
    ) public {
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
        archemist.transferErc20TotalBalance(tokenToWithdraw);
        assertEq(archemist.paused(), true);
    }

    /**
     * [ERROR] Should revert when trying to transfer if there are no assets to transfer.
     */
    function testCannotTransferErc20TotalBalanceNoBalance() public {
        vm.expectRevert(abi.encodeWithSelector(IArchemist.ZeroTokenBalance.selector));

        vm.prank(admin);
        archemist.transferErc20TotalBalance(address(AEDY));
    }

    /*//////////////////////////////////////////////////////////////
                              SUCCESS
    //////////////////////////////////////////////////////////////*/

    /**
     * [SUCCESS] Should transfer all erc20 token balance to the manager when called by admin.
     */
    function testTransferErc20TotalBalanceAsAdmin(uint128 randomUint) public {
        vm.assume(randomUint != 0);

        deal(AEDY, address(archemist), randomUint);

        vm.prank(admin);
        archemist.transferErc20TotalBalance(AEDY);

        assertEq(IERC20(AEDY).balanceOf(address(archemist)), 0);
        assertEq(IERC20(AEDY).balanceOf(admin), randomUint);
        assertEq(archemist.paused(), true);
    }

    /**
     * [SUCCESS] Should transfer all erc20 token balance to the manager when called by manager.
     */
    function testTransferErc20TotalBalanceAsManager(uint128 randomUint, address manager) public {
        vm.assume(manager != address(0x0));
        vm.assume(randomUint != 0);

        deal(AEDY, address(archemist), randomUint);

        vm.prank(admin);
        archemist.addManager(manager);

        vm.prank(manager);
        archemist.transferErc20TotalBalance(AEDY);

        assertEq(IERC20(AEDY).balanceOf(address(archemist)), 0);
        assertEq(IERC20(AEDY).balanceOf(manager), randomUint);
        assertEq(archemist.paused(), true);
    }
}
