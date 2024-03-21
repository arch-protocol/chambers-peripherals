// SPDX-License-Identifier: Apache License 2.0
pragma solidity ^0.8.24;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

import { ArchNexusTest } from "test/utils/ArchNexusTest.sol";
import { IArchNexus } from "src/interfaces/IArchNexus.sol";

contract TransferNativeTokenToOwnerTest is ArchNexusTest {
    /*//////////////////////////////////////////////////////////////
                               REVERT
    //////////////////////////////////////////////////////////////*/

    /**
     * [REVERT] Should revert if the caller is not owner.
     */
    function test_cannotTransferNativeTokenToOwnerNotOwner(address randomAddress) public {
        vm.assume(randomAddress != admin);
        vm.assume(randomAddress != address(0));
        vm.expectRevert(
            abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, randomAddress)
        );
        vm.prank(randomAddress);
        archNexus.transferNativeTokenToOwner();
    }

    /**
     * [REVERT] Should revert if there is no balance for the token.
     */
    function test_cannotTransferNativeTokenToOwnerZeroBalance() public {
        vm.expectRevert(IArchNexus.ZeroBalanceAsset.selector);
        vm.prank(admin);
        archNexus.transferNativeTokenToOwner();
    }

    /*//////////////////////////////////////////////////////////////
                               SUCCESS
    //////////////////////////////////////////////////////////////*/

    /**
     * [SUCCESS] Should transfer all the balance of the token to the owner.
     */
    function test_transferNativeTokenToOwnerAsOwner() public {
        deal(address(archNexus), 100 ether);
        vm.prank(admin);
        archNexus.transferNativeTokenToOwner();
        assertEq(address(archNexus).balance, 0);
    }
}
