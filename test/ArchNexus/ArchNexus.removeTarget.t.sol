// SPDX-License-Identifier: Apache License 2.0
pragma solidity ^0.8.24;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

import { ArchNexusTest } from "test/utils/ArchNexusTest.sol";
import { IArchNexus } from "src/interfaces/IArchNexus.sol";

contract RemoveTargetTest is ArchNexusTest {
    /*//////////////////////////////////////////////////////////////
                               REVERT
    //////////////////////////////////////////////////////////////*/

    /**
     * [REVERT] Should revert if the caller is not owner.
     */
    function test_cannotRemoveTargetNotOwner(address randomAddress, address target) public {
        vm.assume(randomAddress != admin);
        vm.expectRevert(
            abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, randomAddress)
        );
        vm.prank(randomAddress);
        archNexus.removeTarget(target);
    }

    /**
     * [REVERT] Should revert if the target is not allowed.
     */
    function test_cannotRemoveTargetNotAllowed() public {
        address target = vm.addr(0x12323);
        vm.expectRevert(abi.encodeWithSelector(IArchNexus.InvalidTarget.selector, target));
        vm.prank(admin);
        archNexus.removeTarget(target);
    }

    /*//////////////////////////////////////////////////////////////
                               SUCCESS
    //////////////////////////////////////////////////////////////*/

    /**
     * [SUCCESS] Should remove a target from nexus as owner.
     */
    function test_removeTargetAsOwner(address target) public {
        vm.assume(target != address(0));
        vm.startPrank(admin);
        archNexus.addTarget(target);
        archNexus.removeTarget(target);
        vm.stopPrank();
    }
}
