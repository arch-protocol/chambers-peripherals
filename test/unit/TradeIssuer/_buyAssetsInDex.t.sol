// Copyright 2022 Smash Works Inc.
// SPDX-License-Identifier: Apache License 2.0
pragma solidity ^0.8.17.0;

import "forge-std/Test.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { ExposedTradeIssuer } from "test/utils/ExposedTradeIssuer.sol";

contract TradeIssuerUnitInternalBuyAssetsInDexTest is Test {
    /*//////////////////////////////////////////////////////////////
                              VARIABLES
    //////////////////////////////////////////////////////////////*/
    ExposedTradeIssuer public tradeIssuer;
    address public tradeIssuerAddress;
    address payable public dexAgg = payable(address(0x1));
    address public dAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    address public wETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address public inputToken = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48; // USDC on Ethereum
    bytes[] public quotes = new bytes[](2);
    address[] public components = new address[](2);
    uint256[] public componentsQuantities = new uint256[](2);

    /*//////////////////////////////////////////////////////////////
                              SET UP
    //////////////////////////////////////////////////////////////*/

    function setUp() public {
        tradeIssuer = new ExposedTradeIssuer(dexAgg, wETH);
        tradeIssuerAddress = address(tradeIssuer);
        vm.label(tradeIssuerAddress, "TradeIssuer");

        components[0] = dAI;
        components[1] = wETH;

        quotes[0] = bytes("0x0123456");
        quotes[1] = bytes("0x6543210");

        componentsQuantities[0] = 50 ether;
        componentsQuantities[1] = 0.2 ether;
    }

    /*//////////////////////////////////////////////////////////////
                              REVERT
    //////////////////////////////////////////////////////////////*/

    /**
     * [REVERT] Should revert because the first quote didn't transfer any assets to the contract.
     * Hence underbought asset check is triggered after the first quote call.
     */
    function testCannotSwapFillSeconfQuoteWithUnderboughtAssetAtPreviousSwap() public {
        vm.mockCall(dexAgg, quotes[0], abi.encode(componentsQuantities[0]));

        vm.expectCall(dexAgg, quotes[0]);

        vm.expectRevert(bytes("Underbought dex asset"));
        tradeIssuer.buyAssetsInDex(quotes, IERC20(inputToken), components, componentsQuantities, 5);
    }

    /**
     * [REVERT] Should revert after filling the quote for the second component because no token will
     * be transfered after the mockCall. 'Underbought dex asset' check should be triggered.
     * In this scenario the contract has the required input token balance.
     */
    function testCannotSwapInputTokenAsFirstComponentAndInputTokenBalance() public {
        components[0] = inputToken;
        componentsQuantities[0] = 1 ether;

        deal(inputToken, tradeIssuerAddress, 1 ether);

        vm.mockCall(dexAgg, quotes[1], abi.encode(componentsQuantities[1]));

        vm.expectCall(dexAgg, quotes[1]);

        vm.expectRevert(bytes("Underbought dex asset"));
        uint256 totalInputTokensUsed = tradeIssuer.buyAssetsInDex(
            quotes, IERC20(inputToken), components, componentsQuantities, 5
        );

        assertEq(totalInputTokensUsed, 0);
    }

    /**
     * [REVERT] Should revert after filling the quote for the second component because no token will
     * be transfered after the mockCall. 'Underbought dex asset' check should be triggered.
     * In this scenario the contract has no input token balance and the function should return
     * successfully. The check of this scenario (IT CAN HAPPEN) is at the main external functions
     * of the contract and it reverts with 'Overspent input token".
     */
    function testCannotSwapInputTokenAsFirstComponentAndZeroInputTokenBalance() public {
        components[0] = inputToken;
        componentsQuantities[0] = 1 ether;

        vm.mockCall(dexAgg, quotes[1], abi.encode(componentsQuantities[1]));

        vm.expectCall(dexAgg, quotes[1]);

        vm.expectRevert(bytes("Underbought dex asset"));
        uint256 totalInputTokensUsed = tradeIssuer.buyAssetsInDex(
            quotes, IERC20(inputToken), components, componentsQuantities, 5
        );

        assertEq(totalInputTokensUsed, 0);
    }

    /**
     * [REVERT] Should revert because the quantities array is empty while the components array isn't.
     * This scenario should NEVER happen because a check for this is done preemtively at the main external
     * external functions.
     */
    function testCannotSwapWithEmptyQuantitiesArray() public {
        uint256[] memory emptyComponentsQuantities = new uint256[](0);

        vm.expectRevert(stdError.indexOOBError); //Index Out of bounds stdError
        tradeIssuer.buyAssetsInDex(
            quotes, IERC20(inputToken), components, emptyComponentsQuantities, 5
        );
    }

    /**
     * [REVERT] Should revert becasue component quantities are zero.
     */
    function testBuyDexAssetsWithEmptyQuantities() public {
        componentsQuantities[0] = 0;
        componentsQuantities[1] = 0;

        vm.expectRevert(bytes("Cannot buy zero tokens"));
        tradeIssuer.buyAssetsInDex(quotes, IERC20(inputToken), components, componentsQuantities, 5);
    }

    /*//////////////////////////////////////////////////////////////
                              SUCCESS
    //////////////////////////////////////////////////////////////*/

    /**
     * [SUCCESS] inputTokens should be 0 because components array and componentsQuantities are empty.
     */
    function testBuyDexAssetsWithEmptyComponents() public {
        address[] memory emptyComponents = new address[](0);
        uint256[] memory emptyComponentsQuantities = new uint256[](0);

        uint256 totalInputTokensUsed = tradeIssuer.buyAssetsInDex(
            quotes, IERC20(inputToken), emptyComponents, emptyComponentsQuantities, 5
        );

        assertEq(totalInputTokensUsed, 0);
    }

    /**
     * [SUCCESS] Shouldn't fill a quote since the components array only has the input token.
     * In this scenario the contract has the required input token balance.
     */
    function testSwapOnlyInputTokenAndInputTokenBalance() public {
        address[] memory inputTokenArray = new address[](1);
        uint256[] memory inputTokenQuantity = new uint256[](1);

        deal(inputToken, tradeIssuerAddress, 1 ether);

        uint256 inputTokenBalanceBefore = IERC20(inputToken).balanceOf(tradeIssuerAddress);
        inputTokenArray[0] = inputToken;
        inputTokenQuantity[0] = 1 ether;

        uint256 totalInputTokensUsed = tradeIssuer.buyAssetsInDex(
            quotes, IERC20(inputToken), inputTokenArray, inputTokenQuantity, 5
        );

        uint256 inputTokenBalanceAfter = IERC20(inputToken).balanceOf(tradeIssuerAddress);

        assertEq(inputTokenBalanceBefore, 1 ether);
        assertEq(inputTokenBalanceAfter, 1 ether);
        assertEq(totalInputTokensUsed, 1 ether);
    }

    /**
     * [SUCCESS] Shouldnt fill a quote since the components array only has the input token.
     * In this scenario the contract has no input token balance and the function should return
     * successfully. The check of this scenario (IT CAN HAPPEN) is at the main external functions
     * of the contract and it reverts with 'Overspent input token".
     */
    function testSwapOnlyInputTokenAndZeroInputTokenBalance() public {
        address[] memory inputTokenArray = new address[](1);
        uint256[] memory inputTokenQuantity = new uint256[](1);

        uint256 inputTokenBalanceBefore = IERC20(inputToken).balanceOf(tradeIssuerAddress);
        inputTokenArray[0] = inputToken;
        inputTokenQuantity[0] = 1 ether;

        uint256 totalInputTokensUsed = tradeIssuer.buyAssetsInDex(
            quotes, IERC20(inputToken), inputTokenArray, inputTokenQuantity, 5
        );

        uint256 inputTokenBalanceAfter = IERC20(inputToken).balanceOf(tradeIssuerAddress);

        assertEq(inputTokenBalanceBefore, 0 ether);
        assertEq(inputTokenBalanceAfter, 0 ether);
        assertEq(totalInputTokensUsed, 1 ether);
    }
}
