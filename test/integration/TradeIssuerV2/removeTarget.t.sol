// Copyright 2023 Smash Works Inc.
// SPDX-License-Identifier: Apache License 2.0
pragma solidity ^0.8.17.0;

import "forge-std/Test.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { TradeIssuerV2 } from "src/TradeIssuerV2.sol";
import { ITradeIssuerV2 } from "src/interfaces/ITradeIssuerV2.sol";

contract TradeIssuerV2RemoveTargetTest is Test {
    using SafeERC20 for IERC20;

    /*//////////////////////////////////////////////////////////////
                              VARIABLES
    //////////////////////////////////////////////////////////////*/

    TradeIssuerV2 public tradeIssuer;
    mapping(string => address) public tokens;
    address payable public alice = payable(address(0x123456));
    address public target = address(0x987654);

    /*//////////////////////////////////////////////////////////////
                              SET UP
    //////////////////////////////////////////////////////////////*/

    function setUp() public {
        tokens["weth"] = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

        tradeIssuer = new TradeIssuerV2(tokens["weth"]);
        tradeIssuer.addTarget(target);

        tradeIssuer.transferOwnership(alice);

        vm.label(alice, "Alice");
    }

    /*//////////////////////////////////////////////////////////////
                              REVERT
    //////////////////////////////////////////////////////////////*/

    /**
     * [REVERT] Should call removeTarget() and revert because caller is not owner
     */
    function testCannotRemoveTargetWithoutOwnership() public {
        vm.expectRevert("Ownable: caller is not the owner");
        tradeIssuer.removeTarget(target);
    }

    /**
     * [REVERT] Should call removeTarget() and revert because target is not in allowedTargets enumerableSet.
     */
    function testCannotRemoveTargetNotInAllowedTargets() public {
        vm.expectRevert(
            abi.encodeWithSelector(ITradeIssuerV2.InvalidTarget.selector, tokens["weth"])
        );
        vm.prank(alice);
        tradeIssuer.removeTarget(tokens["weth"]);
    }

    /*//////////////////////////////////////////////////////////////
                              SUCCESS
    //////////////////////////////////////////////////////////////*/

    /**
     * [SUCCESS] The function removeTarget should remove the target from the allowedTargets enumerableSet
     * if caller is Owner and the target is in the allowedTargets.
     */
    function testRemoveTargetWithOwner() public {
        bool validTarget = tradeIssuer.isAllowedTarget(target);
        assertEq(validTarget, true);
        vm.prank(alice);
        tradeIssuer.removeTarget(target);
        validTarget = tradeIssuer.isAllowedTarget(alice);
        assertEq(validTarget, false);
    }
}
