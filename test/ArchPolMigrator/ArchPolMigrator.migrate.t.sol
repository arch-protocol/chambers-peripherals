// SPDX-License-Identifier: Apache License 2.0
pragma solidity ^0.8.24;

import { ArchPolMigratorTest } from "test/utils/ArchPolMigratorTest.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract MigrateTest is ArchPolMigratorTest {
    /*//////////////////////////////////////////////////////////////
                               REVERT
    //////////////////////////////////////////////////////////////*/

    /**
     * [REVERT] Should revert if no balance.
     */
    function test_cannotMigrateNoBalance() public {
        vm.startPrank(ALICE);
        IERC20(MATIC).approve(address(archPolMigrator), 10000 ether);
        vm.expectRevert();
        archPolMigrator.migrate(10000 ether);
        assertEq(IERC20(MATIC).balanceOf(address(ALICE)), 0);
        assertEq(IERC20(MATIC).balanceOf(address(archPolMigrator)), 0);
        assertEq(IERC20(POL).balanceOf(address(ALICE)), 0);
        assertEq(IERC20(POL).balanceOf(address(archPolMigrator)), 0);
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                               SUCCESS
    //////////////////////////////////////////////////////////////*/

    /**
     * [SUCCESS] Should migrate successfully and return a value.
     */
    function test_migrate() public {
        deal(MATIC, ALICE, 10000 ether);
        vm.startPrank(ALICE);
        IERC20(MATIC).approve(address(archPolMigrator), 10000 ether);
        uint256 amount = archPolMigrator.migrate(10000 ether);
        vm.stopPrank();
        assertEq(amount, 10000 ether);
        assertEq(IERC20(MATIC).balanceOf(address(ALICE)), 0);
        assertEq(IERC20(MATIC).balanceOf(address(archPolMigrator)), 0);
        assertEq(IERC20(POL).balanceOf(address(ALICE)), 10000 ether);
        assertEq(IERC20(POL).balanceOf(address(archPolMigrator)), 0);
    }

    /**
     * [SUCCESS] Should migrate successfully with low level call.
     */
    function test_migrateWithCallData() public {
        deal(MATIC, ALICE, 10000 ether);
        vm.startPrank(ALICE);
        IERC20(MATIC).approve(address(archPolMigrator), 10000 ether);

        bytes memory data = abi.encodeWithSignature("migrate(uint256)", 10000 ether);
        (bool success, bytes memory response) = address(archPolMigrator).call(data);

        vm.stopPrank();

        require(response.length > 0, "Low level functionCall failed");
        uint256 amount = abi.decode(response, (uint256));

        assertEq(success, true);
        assertEq(amount, 10000 ether);
        assertEq(IERC20(MATIC).balanceOf(address(ALICE)), 0);
        assertEq(IERC20(MATIC).balanceOf(address(archPolMigrator)), 0);
        assertEq(IERC20(POL).balanceOf(address(ALICE)), 10000 ether);
        assertEq(IERC20(POL).balanceOf(address(archPolMigrator)), 0);
    }
}
