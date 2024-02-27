// SPDX-License-Identifier: Apache License 2.0
pragma solidity ^0.8.24;

import { ArchemistTest } from "test/utils/ArchemistTest.sol";
import { IArchemist } from "src/interfaces/IArchemist.sol";
import { IAccessManager } from "src/interfaces/IAccessManager.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract ArchemistTransferErc20ToManager is ArchemistTest {
    /*//////////////////////////////////////////////////////////////
                              REVERT
    //////////////////////////////////////////////////////////////*/

    /**
     * [ERROR] Should revert when trying to transfer erc20 to manager if not admin.
     */
    function testCannotTransferErc20ToManagerNotAdmin(address randomCaller, address tokenToWithdraw)
        public
    {
        vm.assume(randomCaller != admin);
        vm.expectRevert(
            abi.encodeWithSelector(IAccessManager.CallerIsNotManager.selector, randomCaller)
        );
        vm.prank(randomCaller);
        archemist.transferErc20ToManager(tokenToWithdraw);
        assertEq(archemist.paused(), true);
    }

    /**
     * [ERROR] Should revert when trying to transfer erc20 to manager if not admin nor manager.
     */
    function testCannotTransferErc20TomanagerNotAdminNorManager(
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
        archemist.transferErc20ToManager(tokenToWithdraw);
        assertEq(archemist.paused(), true);
    }

    /**
     * [ERROR] Should revert when trying to transfer erc20 to manager if not admin nor manager nor operator.
     */
    function testCannotTransferErc20ToManagerAsOperator(
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
        archemist.transferErc20ToManager(tokenToWithdraw);
        assertEq(archemist.paused(), true);
    }

    /**
     * [ERROR] Should revert when trying to transfer if there are no assets to transfer.
     */
    function testCannotTransferErc20ToManagerNoBalance() public {
        vm.expectRevert(abi.encodeWithSelector(IArchemist.ZeroTokenBalance.selector));

        vm.prank(admin);
        archemist.transferErc20ToManager(address(AEDY));
    }

    /*//////////////////////////////////////////////////////////////
                              SUCCESS
    //////////////////////////////////////////////////////////////*/

    /**
     * [SUCCESS] Should transfer erc20 tokens to the manager when called by admin.
     */
    function testTransferErcToManager20AsAdmin(uint128 randomUint) public {
        vm.assume(randomUint != 0);

        deal(AEDY, address(archemist), randomUint);

        vm.prank(admin);
        archemist.transferErc20ToManager(AEDY);

        assertEq(IERC20(AEDY).balanceOf(address(archemist)), 0);
        assertEq(IERC20(AEDY).balanceOf(admin), randomUint);
        assertEq(archemist.paused(), true);
    }

    /**
     * [SUCCESS] Should transfer erc20 tokens to the manager when called by manager.
     */
    function testTransferErc20AsToManagerManager(uint128 randomUint, address manager) public {
        vm.assume(randomUint != 0);

        deal(AEDY, address(archemist), randomUint);

        vm.prank(admin);
        archemist.addManager(manager);

        vm.prank(manager);
        archemist.transferErc20ToManager(AEDY);

        assertEq(IERC20(AEDY).balanceOf(address(archemist)), 0);
        assertEq(IERC20(AEDY).balanceOf(manager), randomUint);
        assertEq(archemist.paused(), true);
    }
}
