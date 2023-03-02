// Copyright 2023 Smash Works Inc.
// SPDX-License-Identifier: Apache License 2.0
pragma solidity ^0.8.17.0;

import "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {TradeIssuerV2} from "src/TradeIssuerV2.sol";
import {ITradeIssuerV2} from "src/interfaces/ITradeIssuerV2.sol";

contract TradeIssuerV2AddTargetTest is Test {
    using SafeERC20 for IERC20;

    /*//////////////////////////////////////////////////////////////
                              VARIABLES
    //////////////////////////////////////////////////////////////*/

    TradeIssuerV2 public tradeIssuer;
    mapping(string => address) public tokens;
    address payable public alice = payable(address(0x123456));
    address public newTarget = address(0x987654);

    /*//////////////////////////////////////////////////////////////
                              SET UP
    //////////////////////////////////////////////////////////////*/

    function setUp() public {
        tokens["weth"] = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

        tradeIssuer = new TradeIssuerV2( tokens["weth"]);

        tradeIssuer.transferOwnership(alice);

        vm.label(alice, "Alice");
    }

    /*//////////////////////////////////////////////////////////////
                              SUCCESS
    //////////////////////////////////////////////////////////////*/

    /**
     * [SUCCESS] The function addTarget should add the target to the allowedTargets enumerableSet
     * if caller is Owner and the target is not in allowedTargets.
     */
    function testAddTargetWithOwner() public {
        vm.prank(alice);
        tradeIssuer.addTarget(newTarget);
        address[] memory targets = tradeIssuer.getAllowedTargets();
        assertEq(targets[0], newTarget);
    }

    /*//////////////////////////////////////////////////////////////
                              REVERT
    //////////////////////////////////////////////////////////////*/

    /**
     * [REVERT] Should call addTarget() and revert because caller is not owner
     */
    function testCannotAddTargetWithoutOwnership() public {
        vm.expectRevert("Ownable: caller is not the owner");
        tradeIssuer.addTarget(newTarget);
    }

    /**
     * [REVERT] Should call addTarget() and revert because the atrget is already in allowedTargets enumerableSet.
     */
    function testCannotAddAdminAlreadyInUserAdmin() public {
        vm.prank(alice);
        tradeIssuer.addTarget(alice);
        vm.expectRevert(ITradeIssuerV2.TargetAlreadyAllowed.selector);
        vm.prank(alice);
        tradeIssuer.addTarget(alice);
    }
}
