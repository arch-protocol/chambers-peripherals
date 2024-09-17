// SPDX-License-Identifier: Apache License 2.0
pragma solidity ^0.8.24;

import { ArchemistTest } from "test/utils/ArchemistTest.sol";
import { IArchemist } from "src/interfaces/IArchemist.sol";
import { IAccessManager } from "src/interfaces/IAccessManager.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ArchPolMigratorTest } from "test/utils/ArchPolMigratorTest.sol";

contract ArchPolMigratorTransferERC20ToOwner is ArchPolMigratorTest {
    /*//////////////////////////////////////////////////////////////
                              REVERT
    //////////////////////////////////////////////////////////////*/

    /**
     * [ERROR] Should revert when trying to transfer all erc20 token balance if not admin.
     */
    function testCannotTransferERC20ToOwnerNotAdmin(address randomCaller, address tokenToWithdraw)
        public
    {
        vm.assume(randomCaller != admin);
        vm.prank(randomCaller);
        vm.expectRevert();
        archPolMigrator.transferERC20ToOwner(tokenToWithdraw);
    }

    /**
     * [ERROR] Should revert when trying to transfer if there are no assets to transfer.
     */
    function testCannotTransferERC20ToOwnerNoBalance() public {
        vm.expectRevert("NO_BALANCE");

        vm.prank(admin);
        archPolMigrator.transferERC20ToOwner(address(POL));
    }

    /*//////////////////////////////////////////////////////////////
                              SUCCESS
    //////////////////////////////////////////////////////////////*/

    /**
     * [SUCCESS] Should transfer all erc20 token balance to the manager when called by admin.
     */
    function testTransferERC20ToOwnerAsAdmin(uint128 randomUint) public {
        vm.assume(randomUint != 0);

        deal(POL, address(archPolMigrator), randomUint);

        vm.prank(admin);
        archPolMigrator.transferERC20ToOwner(address(POL));

        assertEq(IERC20(POL).balanceOf(address(archPolMigrator)), 0);
        assertEq(IERC20(POL).balanceOf(admin), randomUint);
    }
}
