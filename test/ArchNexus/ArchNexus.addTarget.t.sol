// SPDX-License-Identifier: Apache License 2.0
pragma solidity ^0.8.24;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

import { ArchNexusTest } from "test/utils/ArchNexusTest.sol";
import { IArchNexus } from "src/interfaces/IArchNexus.sol";

contract AddTargetTest is ArchNexusTest {
    /*//////////////////////////////////////////////////////////////
                               REVERT
    //////////////////////////////////////////////////////////////*/

    /**
     * [REVERT] Should revert if the caller is not owner.
     */
    function test_cannotAddTargetNotOwner() public {
        address randomAddress = vm.addr(0x123123);
        vm.expectRevert(
            abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, randomAddress)
        );
        vm.prank(randomAddress);
        archNexus.addTarget(vm.addr(0x123123));
    }

    /**
     * [REVERT] Should revert if the target is already allowed.
     */
    function test_cannotAddTargetAlreadyAllowed() public {
        address target = vm.addr(0x123123);
        vm.prank(admin);
        archNexus.addTarget(target);
        vm.expectRevert(IArchNexus.TargetAlreadyAllowed.selector);
        vm.prank(admin);
        archNexus.addTarget(target);
    }

    /*//////////////////////////////////////////////////////////////
                               SUCCESS
    //////////////////////////////////////////////////////////////*/

    /**
     * [SUCCESS] Should add target to nexus as owner.
     */
    function test_addTargetAsOwner() public {
        address target = vm.addr(0x123123);
        vm.prank(admin);
        archNexus.addTarget(target);
    }
}
