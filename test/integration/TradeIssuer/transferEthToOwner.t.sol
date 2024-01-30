// Copyright 2022 Smash Works Inc.
// SPDX-License-Identifier: Apache License 2.0
pragma solidity ^0.8.17.0;

import "forge-std/Test.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { ExposedTradeIssuer } from "test/utils/ExposedTradeIssuer.sol";

contract TradeIssuerIntegrationTransferEthToOwnerTest is Test {
    using SafeERC20 for IERC20;

    /*//////////////////////////////////////////////////////////////
                              VARIABLES
    //////////////////////////////////////////////////////////////*/

    ExposedTradeIssuer public tradeIssuer;
    address public tradeIssuerAddress;
    address payable public dexAgg = payable(address(0x1));
    address payable public alice = payable(address(0x2));
    address public wETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2; // WETH on ETH

    /*//////////////////////////////////////////////////////////////
                              SET UP
    //////////////////////////////////////////////////////////////*/

    function setUp() public {
        tradeIssuer = new ExposedTradeIssuer(dexAgg, wETH);
        tradeIssuerAddress = address(tradeIssuer);
        vm.label(tradeIssuerAddress, "TradeIssuer");

        tradeIssuer.transferOwnership(alice);
    }

    /*//////////////////////////////////////////////////////////////
                              REVERT
    //////////////////////////////////////////////////////////////*/

    /**
     * [REVERT] Should revert if the caller is not the owner
     */
    function testCannotTransferIfMsgSenderIsNotTheOwner(address caller, uint64 someBalance)
        public
    {
        vm.assume(caller != alice);
        vm.deal(tradeIssuerAddress, someBalance);

        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(caller);
        tradeIssuer.transferEthToOwner();

        assertEq(tradeIssuerAddress.balance, someBalance);
    }

    /**
     * [REVERT] Should revert if the contract does not have balance of the token.
     */
    function testCannotTransferWithoutBalance() public {
        uint256 balanceBefore = alice.balance;
        if (tradeIssuerAddress.balance > 0) {
            vm.prank(tradeIssuerAddress);
            payable(0x0).transfer(tradeIssuerAddress.balance);
        }
        vm.expectRevert("No Native Token balance");
        vm.prank(alice);
        tradeIssuer.transferEthToOwner();

        assertEq(alice.balance - balanceBefore, 0);
    }

    /*//////////////////////////////////////////////////////////////
                              SUCCESS
    //////////////////////////////////////////////////////////////*/

    /**
     * [SUCCESS] Should transfer all the balance to the owner if the caller is the owner
     */
    function testTransfer(uint64 someBalance) public {
        vm.assume(someBalance > 0);
        uint256 balanceBefore = alice.balance;

        if (tradeIssuerAddress.balance > 0) {
            vm.prank(tradeIssuerAddress);
            payable(0x0).transfer(tradeIssuerAddress.balance);
        }

        vm.deal(tradeIssuerAddress, someBalance);

        vm.prank(alice);
        tradeIssuer.transferEthToOwner();

        assertEq(tradeIssuerAddress.balance, 0);
        assertEq(alice.balance - balanceBefore, someBalance);
    }
}
