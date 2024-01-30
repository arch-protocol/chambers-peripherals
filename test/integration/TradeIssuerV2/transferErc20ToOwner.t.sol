// Copyright 2022 Smash Works Inc.
// SPDX-License-Identifier: Apache License 2.0
pragma solidity ^0.8.17.0;

import "forge-std/Test.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { TradeIssuerV2 } from "src/TradeIssuerV2.sol";
import { ITradeIssuerV2 } from "src/interfaces/ITradeIssuerV2.sol";

contract TradeIssuerV2IntegrationTransferErc20ToOwnerTest is Test {
    using SafeERC20 for IERC20;

    /*//////////////////////////////////////////////////////////////
                              VARIABLES
    //////////////////////////////////////////////////////////////*/

    TradeIssuerV2 public tradeIssuer;
    address payable public alice = payable(address(0x123456));
    mapping(string => address) public tokens;

    /*//////////////////////////////////////////////////////////////
                              SET UP
    //////////////////////////////////////////////////////////////*/

    function setUp() public {
        tokens["weth"] = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

        tradeIssuer = new TradeIssuerV2(tokens["weth"]);

        tradeIssuer.transferOwnership(alice);

        vm.label(alice, "Alice");
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
        deal(tokens["weth"], address(tradeIssuer), someBalance);

        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(caller);
        tradeIssuer.transferERC20ToOwner(tokens["weth"]);

        assertEq(IERC20(tokens["weth"]).balanceOf(address(tradeIssuer)), someBalance);
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

        vm.expectRevert(ITradeIssuerV2.ZeroBalanceAsset.selector);
        vm.prank(alice);
        tradeIssuer.transferERC20ToOwner(tokens["weth"]);
    }

    /*//////////////////////////////////////////////////////////////
                              SUCCESS
    //////////////////////////////////////////////////////////////*/

    /**
     * [SUCCESS] Should transfer all the balance to the owner if the caller is the owner
     */
    function testTransfer(uint64 someBalance) public {
        vm.assume(someBalance > 0);
        deal(tokens["weth"], address(tradeIssuer), someBalance);

        vm.prank(alice);
        tradeIssuer.transferERC20ToOwner(tokens["weth"]);

        assertEq(IERC20(tokens["weth"]).balanceOf(address(tradeIssuer)), 0);
        assertEq(IERC20(tokens["weth"]).balanceOf(alice), someBalance);
    }
}
