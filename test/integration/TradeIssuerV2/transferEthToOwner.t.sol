// Copyright 2022 Smash Works Inc.
// SPDX-License-Identifier: Apache License 2.0
pragma solidity ^0.8.17.0;

import "forge-std/Test.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { TradeIssuerV2 } from "src/TradeIssuerV2.sol";
import { ITradeIssuerV2 } from "src/interfaces/ITradeIssuerV2.sol";

contract TradeIssuerV2IntegrationTransferEthToOwnerTest is Test {
    using SafeERC20 for IERC20;

    /*//////////////////////////////////////////////////////////////
                              VARIABLES
    //////////////////////////////////////////////////////////////*/

    TradeIssuerV2 public tradeIssuer;
    mapping(string => address) public tokens;
    address payable public alice = payable(address(0x123456));

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
        vm.deal(address(tradeIssuer), someBalance);

        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(caller);
        tradeIssuer.transferEthToOwner();

        assertEq(address(tradeIssuer).balance, someBalance);
    }

    /**
     * [REVERT] Should revert if the contract does not have balance of the token.
     */
    function testCannotTransferWithoutBalance() public {
        uint256 balanceBefore = alice.balance;
        if (address(tradeIssuer).balance > 0) {
            vm.prank(address(tradeIssuer));
            payable(0x0).transfer(address(tradeIssuer).balance);
        }
        vm.expectRevert(ITradeIssuerV2.ZeroBalanceAsset.selector);
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

        if (address(tradeIssuer).balance > 0) {
            vm.prank(address(tradeIssuer));
            payable(0x0).transfer(address(tradeIssuer).balance);
        }

        vm.deal(address(tradeIssuer), someBalance);

        vm.prank(alice);
        tradeIssuer.transferEthToOwner();

        assertEq(address(tradeIssuer).balance, 0);
        assertEq(alice.balance - balanceBefore, someBalance);
    }
}
