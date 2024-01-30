// Copyright 2023 Smash Works Inc.
// SPDX-License-Identifier: Apache License 2.0
pragma solidity ^0.8.17.0;

import "forge-std/Test.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { TradeIssuerV2 } from "src/TradeIssuerV2.sol";
import { ITradeIssuerV2 } from "src/interfaces/ITradeIssuerV2.sol";

contract TradeIssuerV2IsAllowedTargetTest is Test {
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
                              SUCCESS
    //////////////////////////////////////////////////////////////*/

    /**
     * [SUCCESS] Should return true if the allowedTarget is in the allowedTargets enumerableSet.
     */
    function testIsAllowedTarget() public {
        bool validTarget = tradeIssuer.isAllowedTarget(target);
        assertEq(validTarget, true);
    }

    /**
     * [SUCCESS] Should return false if the allowedTarget is not in the allowedTargets enumerableSet.
     */
    function testIsNotAllowedTarget() public {
        address invalidTarget = address(0x111111);
        bool validTarget = tradeIssuer.isAllowedTarget(invalidTarget);
        assertEq(validTarget, false);
    }
}
