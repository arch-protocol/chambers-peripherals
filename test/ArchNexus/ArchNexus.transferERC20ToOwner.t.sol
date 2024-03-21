// SPDX-License-Identifier: Apache License 2.0
pragma solidity ^0.8.24;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

import { ArchNexusTest } from "test/utils/ArchNexusTest.sol";
import { IArchNexus } from "src/interfaces/IArchNexus.sol";

contract TransferERC20ToOwnerTest is ArchNexusTest {
    /*//////////////////////////////////////////////////////////////
                               REVERT
    //////////////////////////////////////////////////////////////*/

    /**
     * [REVERT] Should revert if the caller is not owner.
     */
    function test_cannotTransferERC20ToOwnerNotOwner(address randomAddress) public {
        vm.assume(randomAddress != admin);
        vm.expectRevert(
            abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, randomAddress)
        );
        vm.prank(randomAddress);
        archNexus.transferERC20ToOwner(USDC);
    }

    /**
     * [REVERT] Should revert if there is no balance for the token.
     */
    function test_cannotTransferERC20ToOwnerZeroBalance() public {
        vm.expectRevert(IArchNexus.ZeroBalanceAsset.selector);
        vm.prank(admin);
        archNexus.transferERC20ToOwner(USDC);
    }

    /*//////////////////////////////////////////////////////////////
                               SUCCESS
    //////////////////////////////////////////////////////////////*/

    /**
     * [SUCCESS] Should transfer all the balance of the token to the owner.
     */
    function test_transferERC20ToOwnerAsOwner() public {
        deal(ADDY, address(archNexus), 100 ether);
        vm.prank(admin);
        archNexus.transferERC20ToOwner(ADDY);
    }
}
