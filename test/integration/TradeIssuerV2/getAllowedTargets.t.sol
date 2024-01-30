// Copyright 2023 Smash Works Inc.
// SPDX-License-Identifier: Apache License 2.0
pragma solidity ^0.8.17.0;

import "forge-std/Test.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { TradeIssuerV2 } from "src/TradeIssuerV2.sol";
import { ITradeIssuerV2 } from "src/interfaces/ITradeIssuerV2.sol";

contract TradeIssuerV2GetAllowedTargetsTest is Test {
    /*//////////////////////////////////////////////////////////////
                              VARIABLES
    //////////////////////////////////////////////////////////////*/

    TradeIssuerV2 public tradeIssuer;
    mapping(string => address) public tokens;
    address payable public alice = payable(address(0x123456));
    address[] public targets = new address[](1);
    address public target = address(0x987654);

    /*//////////////////////////////////////////////////////////////
                              SET UP
    //////////////////////////////////////////////////////////////*/

    function setUp() public {
        tokens["weth"] = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

        tradeIssuer = new TradeIssuerV2(tokens["weth"]);
        tradeIssuer.addTarget(target);

        targets[0] = target;

        tradeIssuer.transferOwnership(alice);

        vm.label(alice, "Alice");
    }

    /*//////////////////////////////////////////////////////////////
                              SUCCESS
    //////////////////////////////////////////////////////////////*/

    /**
     * [SUCCESS] Should return an array of the allowedTargets.
     */
    function testGetAllowedTargets() public {
        address[] memory allowedTargets = tradeIssuer.getAllowedTargets();
        assertEq(allowedTargets, targets);
    }

    /**
     * [SUCCESS] Should return an empty allowedTargets array.
     */
    function testShouldReturnEmptyWhenNoAllowedTargets() public {
        address[] memory noTargets = new address[](0);
        vm.prank(alice);
        tradeIssuer.removeTarget(target);
        address[] memory allowedTargets = tradeIssuer.getAllowedTargets();
        assertEq(allowedTargets, noTargets);
    }
}
