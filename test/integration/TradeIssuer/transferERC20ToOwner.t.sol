// Copyright 2022 Smash Works Inc.
// SPDX-License-Identifier: Apache License 2.0
pragma solidity ^0.8.17.0;

import "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ExposedTradeIssuer} from "test/utils/ExposedTradeIssuer.sol";

contract TradeIssuerIntegrationTransferERC20ToOwnerTest is Test {
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
        vm.assume(someBalance > 0);
        deal(wETH, tradeIssuerAddress, someBalance);

        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(caller);
        tradeIssuer.transferERC20ToOwner(wETH);

        assertEq(IERC20(wETH).balanceOf(tradeIssuerAddress), someBalance);
    }

    /**
     * [REVERT] Should revert if the address is not ERC20
     */
    function testFailTransferIfTheAdressIsNotERC20(address notERC20) public {
        vm.prank(alice);
        tradeIssuer.transferERC20ToOwner(notERC20);
    }

    /**
     * [REVERT] Should revert if the contract does not have balance of the token.
     */
    function testCannotTransferWithoutBalance(address caller) public {
        vm.assume(caller != tradeIssuer.owner());

        vm.expectRevert("No ERC20 Balance");
        vm.prank(alice);
        tradeIssuer.transferERC20ToOwner(wETH);
    }

    /*//////////////////////////////////////////////////////////////
                              SUCCESS
    //////////////////////////////////////////////////////////////*/

    /**
     * [SUCCESS] Should transfer all the balance to the owner if the caller is the owner
     */
    function testTransfer(uint64 someBalance) public {
        vm.assume(someBalance > 0);
        deal(wETH, tradeIssuerAddress, someBalance);

        vm.prank(alice);
        tradeIssuer.transferERC20ToOwner(wETH);

        assertEq(IERC20(wETH).balanceOf(tradeIssuerAddress), 0);
        assertEq(IERC20(wETH).balanceOf(alice), someBalance);
    }
}
