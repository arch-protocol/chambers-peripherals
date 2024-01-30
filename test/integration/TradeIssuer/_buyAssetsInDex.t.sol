// Copyright 2022 Smash Works Inc.
// SPDX-License-Identifier: Apache License 2.0
pragma solidity ^0.8.17.0;

import { ChamberTestUtils } from "test/utils/ChamberTestUtils.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { ExposedTradeIssuer } from "test/utils/ExposedTradeIssuer.sol";

contract TradeIssuerIntegrationInternalBuyAssetsInDexTest is ChamberTestUtils {
    /*//////////////////////////////////////////////////////////////
                              VARIABLES
    //////////////////////////////////////////////////////////////*/

    ExposedTradeIssuer public tradeIssuer;
    address public tradeIssuerAddress;
    address payable public zeroExProxy = payable(0xDef1C0ded9bec7F1a1670819833240f027b25EfF); // 0x on ETH
    address public dAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    address public wETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address public inputToken = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48; // USDC on ETH
    bytes[] public quotes = new bytes[](2);
    address[] public components = new address[](2);
    uint256[] public componentsQuantities = new uint256[](2);

    /*//////////////////////////////////////////////////////////////
                              SET UP
    //////////////////////////////////////////////////////////////*/

    function setUp() public {
        tradeIssuer = new ExposedTradeIssuer(zeroExProxy, wETH);
        tradeIssuerAddress = address(tradeIssuer);
        vm.label(tradeIssuerAddress, "TradeIssuer");
        components[0] = dAI;
        components[1] = wETH;
    }

    /*//////////////////////////////////////////////////////////////
                              REVERT
    //////////////////////////////////////////////////////////////*/

    /**
     * [REVERT] Should Revert because there's no approve on the input token.
     */
    function testCannotSwapNoApproveWithTwoComponents(uint64 buyAmount0, uint64 buyAmount1)
        public
    {
        vm.assume(buyAmount0 > (10 ether));
        vm.assume(buyAmount0 < (1000000 ether));
        vm.assume(buyAmount1 > (1 ether));
        vm.assume(buyAmount1 < (1000 ether));

        componentsQuantities[0] = buyAmount0;
        componentsQuantities[1] = buyAmount1;

        uint256 component0BalanceBefore = IERC20(components[0]).balanceOf(tradeIssuerAddress);
        uint256 component1BalanceBefore = IERC20(components[1]).balanceOf(tradeIssuerAddress);

        (bytes memory quote0, uint256 sellAmount0) =
            getQuoteDataForMint(buyAmount0, components[0], inputToken);
        (bytes memory quote1, uint256 sellAmount1) =
            getQuoteDataForMint(buyAmount1, components[1], inputToken);

        quotes[0] = quote0;
        quotes[1] = quote1;

        uint256 amountWithSlippage = ((sellAmount0 + sellAmount1) * 101 / 100);

        deal(inputToken, tradeIssuerAddress, amountWithSlippage);
        uint256 inputTokenBalanceBefore = IERC20(inputToken).balanceOf(tradeIssuerAddress);
        // Approve expected here.

        vm.expectRevert(); // The error message isn't always the same.
        uint256 inputTokensUsed = tradeIssuer.buyAssetsInDex(
            quotes, IERC20(inputToken), components, componentsQuantities, 5
        );

        uint256 component0BalanceAfter = IERC20(components[0]).balanceOf(tradeIssuerAddress);
        uint256 component1BalanceAfter = IERC20(components[1]).balanceOf(tradeIssuerAddress);
        uint256 inputTokenBalanceAfter = IERC20(inputToken).balanceOf(tradeIssuerAddress);

        assertEq(component0BalanceAfter - component0BalanceBefore, 0);
        assertEq(component1BalanceAfter - component1BalanceBefore, 0);
        assertEq(inputTokenBalanceBefore - inputTokenBalanceAfter, inputTokensUsed);
        assertEq(inputTokensUsed, 0);
    }

    /**
     * [REVERT] Should Revert because there's no input token balance.
     */
    function testCannotSwapNoInputTokenBalanceWithTwoComponents(
        uint64 buyAmount0,
        uint64 buyAmount1
    ) public {
        vm.assume(buyAmount0 > (10 ether));
        vm.assume(buyAmount0 < (1000000 ether));
        vm.assume(buyAmount1 > (1 ether));
        vm.assume(buyAmount1 < (1000 ether));

        componentsQuantities[0] = buyAmount0;
        componentsQuantities[1] = buyAmount1;

        uint256 component0BalanceBefore = IERC20(components[0]).balanceOf(tradeIssuerAddress);
        uint256 component1BalanceBefore = IERC20(components[1]).balanceOf(tradeIssuerAddress);

        (bytes memory quote0,) = getQuoteDataForMint(buyAmount0, components[0], inputToken);
        (bytes memory quote1,) = getQuoteDataForMint(buyAmount1, components[1], inputToken);

        quotes[0] = quote0;
        quotes[1] = quote1;

        //Tokens should be dealed here
        uint256 inputTokenBalanceBefore = IERC20(inputToken).balanceOf(tradeIssuerAddress);

        vm.prank(tradeIssuerAddress);
        IERC20(inputToken).approve(zeroExProxy, type(uint256).max);

        vm.expectRevert(); // The error message isn't always the same.
        uint256 inputTokensUsed = tradeIssuer.buyAssetsInDex(
            quotes, IERC20(inputToken), components, componentsQuantities, 5
        );

        uint256 component0BalanceAfter = IERC20(components[0]).balanceOf(tradeIssuerAddress);
        uint256 component1BalanceAfter = IERC20(components[1]).balanceOf(tradeIssuerAddress);
        uint256 inputTokenBalanceAfter = IERC20(inputToken).balanceOf(tradeIssuerAddress);

        assertEq(component0BalanceAfter - component0BalanceBefore, 0);
        assertEq(component1BalanceAfter - component1BalanceBefore, 0);
        assertEq(inputTokenBalanceBefore - inputTokenBalanceAfter, inputTokensUsed);
        assertEq(inputTokensUsed, 0);
    }

    /**
     * [REVERT] Should revert because component quantity is not the same as the one used at the quote.
     */
    function testCannotSwapWithDifferentQuoteAmountAndArrayQuantities(
        uint64 buyAmount0,
        uint64 buyAmount1
    ) public {
        vm.assume(buyAmount0 > (10 ether));
        vm.assume(buyAmount0 < (1000000 ether));
        vm.assume(buyAmount1 > (1 ether));
        vm.assume(buyAmount1 < (1000 ether));

        uint256 bigOrderBuyAmount0 = buyAmount0;

        componentsQuantities[0] = bigOrderBuyAmount0 * 2;
        componentsQuantities[1] = buyAmount1;

        uint256 component0BalanceBefore = IERC20(components[0]).balanceOf(tradeIssuerAddress);
        uint256 component1BalanceBefore = IERC20(components[1]).balanceOf(tradeIssuerAddress);

        (bytes memory quote0, uint256 sellAmount0) =
            getQuoteDataForMint(buyAmount0, components[0], inputToken);
        (bytes memory quote1, uint256 sellAmount1) =
            getQuoteDataForMint(buyAmount1, components[1], inputToken);

        quotes[0] = quote0;
        quotes[1] = quote1;

        uint256 amountWithSlippage = ((sellAmount0 + sellAmount1) * 101 / 100);
        deal(inputToken, tradeIssuerAddress, amountWithSlippage);
        uint256 inputTokenBalanceBefore = IERC20(inputToken).balanceOf(tradeIssuerAddress);

        vm.prank(tradeIssuerAddress);
        IERC20(inputToken).approve(zeroExProxy, type(uint256).max);

        vm.expectRevert(bytes("Underbought dex asset"));
        uint256 inputTokensUsed = tradeIssuer.buyAssetsInDex(
            quotes, IERC20(inputToken), components, componentsQuantities, 5
        );

        uint256 component0BalanceAfter = IERC20(components[0]).balanceOf(tradeIssuerAddress);
        uint256 component1BalanceAfter = IERC20(components[1]).balanceOf(tradeIssuerAddress);
        uint256 inputTokenBalanceAfter = IERC20(inputToken).balanceOf(tradeIssuerAddress);

        assertEq(component0BalanceAfter - component0BalanceBefore, 0);
        assertEq(component1BalanceAfter - component1BalanceBefore, 0);
        assertEq(inputTokenBalanceBefore - inputTokenBalanceAfter, inputTokensUsed);
        assertEq(inputTokensUsed, 0);
    }

    /**
     * [REVERT] Should revert because component quantity is not the same as the one used at the quote.
     */
    function testSwapWithBadQuotes(uint64 buyAmount0, uint64 buyAmount1) public {
        vm.assume(buyAmount0 > (10 ether));
        vm.assume(buyAmount0 < (1000000 ether));
        vm.assume(buyAmount1 > (1 ether));
        vm.assume(buyAmount1 < (1000 ether));

        uint256 bigOrderBuyAmount0 = buyAmount0;

        componentsQuantities[0] = bigOrderBuyAmount0 * 2;
        componentsQuantities[1] = buyAmount1;

        uint256 component0BalanceBefore = IERC20(components[0]).balanceOf(tradeIssuerAddress);
        uint256 component1BalanceBefore = IERC20(components[1]).balanceOf(tradeIssuerAddress);

        (, uint256 sellAmount0) = getQuoteDataForMint(buyAmount0, components[0], inputToken);
        (bytes memory quote1, uint256 sellAmount1) =
            getQuoteDataForMint(buyAmount1, components[1], inputToken);

        quotes[0] = bytes("0x123456"); // Bad Quote
        quotes[1] = quote1;

        uint256 amountWithSlippage = ((sellAmount0 + sellAmount1) * 101 / 100);
        deal(inputToken, tradeIssuerAddress, amountWithSlippage);

        uint256 inputTokenBalanceBefore = IERC20(inputToken).balanceOf(tradeIssuerAddress);

        vm.prank(tradeIssuerAddress);
        IERC20(inputToken).approve(zeroExProxy, type(uint256).max);

        vm.expectRevert(); // Revert message unknown
        uint256 inputTokensUsed = tradeIssuer.buyAssetsInDex(
            quotes, IERC20(inputToken), components, componentsQuantities, 5
        );

        uint256 component0BalanceAfter = IERC20(components[0]).balanceOf(tradeIssuerAddress);
        uint256 component1BalanceAfter = IERC20(components[1]).balanceOf(tradeIssuerAddress);
        uint256 inputTokenBalanceAfter = IERC20(inputToken).balanceOf(tradeIssuerAddress);

        assertEq(component0BalanceAfter - component0BalanceBefore, 0);
        assertEq(component1BalanceAfter - component1BalanceBefore, 0);
        assertEq(inputTokenBalanceBefore - inputTokenBalanceAfter, inputTokensUsed);
        assertEq(inputTokensUsed, 0);
    }

    /*//////////////////////////////////////////////////////////////
                              SUCCESS
    //////////////////////////////////////////////////////////////*/

    /**
     * [SUCCESS] Should call with correct quotes and swap successfully with 0.5% slippage
     * on the upside. Max swap buy quotes are 1.000.000 USDC app.
     */
    function testSwapWithTwoComponents(uint64 buyAmount0, uint64 buyAmount1) public {
        vm.assume(buyAmount0 > (10 ether));
        vm.assume(buyAmount0 < (1000000 ether));
        vm.assume(buyAmount1 > (1 ether));
        vm.assume(buyAmount1 < (1000 ether));

        componentsQuantities[0] = buyAmount0;
        componentsQuantities[1] = buyAmount1;

        uint256 component0BalanceBefore = IERC20(components[0]).balanceOf(tradeIssuerAddress);
        uint256 component1BalanceBefore = IERC20(components[1]).balanceOf(tradeIssuerAddress);
        (bytes memory quote0, uint256 sellAmount0) =
            getQuoteDataForMint(buyAmount0, components[0], inputToken);
        (bytes memory quote1, uint256 sellAmount1) =
            getQuoteDataForMint(buyAmount1, components[1], inputToken);

        quotes[0] = quote0;
        quotes[1] = quote1;

        uint256 amountWithSlippage = ((sellAmount0 + sellAmount1) * 101 / 100);
        deal(inputToken, tradeIssuerAddress, amountWithSlippage);
        uint256 inputTokenBalanceBefore = IERC20(inputToken).balanceOf(tradeIssuerAddress);

        vm.prank(tradeIssuerAddress);
        IERC20(inputToken).approve(zeroExProxy, type(uint256).max);

        uint256 inputTokensUsed = tradeIssuer.buyAssetsInDex(
            quotes, IERC20(inputToken), components, componentsQuantities, 5
        );

        uint256 component0BalanceAfter = IERC20(components[0]).balanceOf(tradeIssuerAddress);
        uint256 component1BalanceAfter = IERC20(components[1]).balanceOf(tradeIssuerAddress);
        uint256 inputTokenBalanceAfter = IERC20(inputToken).balanceOf(tradeIssuerAddress);

        assertLe(
            component0BalanceAfter - component0BalanceBefore,
            (componentsQuantities[0] * 1005) / 1000
        );
        assertLe(
            component1BalanceAfter - component1BalanceBefore,
            (componentsQuantities[1] * 1005) / 1000
        );
        assertEq(inputTokenBalanceBefore - inputTokenBalanceAfter, inputTokensUsed);
    }

    /**
     * [SUCCESS] Should call with correct quotes and swap successfully with 0.5% slippage
     * on the upside. Max swap buy quotes are 1.000.000 USDC app. First token is inputToken with
     * max amount of 1.000.000 USD. Trade issuer has enough inputToken for both "swaps".
     */
    function testSwapWithInputTokenAndOneComponentHavingInputTokenBalance(
        uint64 buyAmountInputToken,
        uint64 buyAmount1
    ) public {
        vm.assume(buyAmountInputToken > (10 ether));
        vm.assume(buyAmountInputToken < (1000000 ether));
        vm.assume(buyAmount1 > (1 ether));
        vm.assume(buyAmount1 < (1000 ether));

        components[0] = inputToken;
        componentsQuantities[0] = buyAmountInputToken;
        componentsQuantities[1] = buyAmount1;

        uint256 component1BalanceBefore = IERC20(components[1]).balanceOf(tradeIssuerAddress);
        (bytes memory quote1, uint256 sellAmount1) =
            getQuoteDataForMint(buyAmount1, components[1], inputToken);

        quotes[1] = quote1;

        uint256 amountWithSlippage = (buyAmountInputToken + (sellAmount1 * 101) / 100);
        deal(inputToken, tradeIssuerAddress, amountWithSlippage);
        uint256 inputTokenBalanceBefore = IERC20(inputToken).balanceOf(tradeIssuerAddress);

        vm.prank(tradeIssuerAddress);
        IERC20(inputToken).approve(zeroExProxy, type(uint256).max);

        uint256 inputTokensUsed = tradeIssuer.buyAssetsInDex(
            quotes, IERC20(inputToken), components, componentsQuantities, 5
        );

        uint256 component1BalanceAfter = IERC20(components[1]).balanceOf(tradeIssuerAddress);
        uint256 inputTokenBalanceAfter = IERC20(inputToken).balanceOf(tradeIssuerAddress);

        assertLe(
            component1BalanceAfter - component1BalanceBefore,
            (componentsQuantities[1] * 1005) / 1000
        );
        assertEq(
            buyAmountInputToken + inputTokenBalanceBefore - inputTokenBalanceAfter, inputTokensUsed
        );
    }

    /**
     * [SUCCESS] Should call with correct quotes and swap successfully with 0.5% slippage
     * on the upside. Max swap buy quotes are 1.000.000 USDC app. First token is inputToken with
     * max amount of 1.000.000 USD. In this case, tradeIssuer doesn't have enough balance for both
     * inputToken quantity and component[1] quantity. The check for this condition is done at the
     * external main functions of the TradeIssuer contract.
     */
    function testSwapWithInputTokenAndOneComponentWithouthInputTokenBalance(
        uint64 buyAmountInputToken,
        uint64 buyAmount1
    ) public {
        vm.assume(buyAmountInputToken > (10 ether));
        vm.assume(buyAmountInputToken < (1000000 ether));
        vm.assume(buyAmount1 > (1 ether));
        vm.assume(buyAmount1 < (1000 ether));

        components[0] = inputToken;
        componentsQuantities[0] = buyAmountInputToken;
        componentsQuantities[1] = buyAmount1;

        uint256 component1BalanceBefore = IERC20(components[1]).balanceOf(tradeIssuerAddress);
        (bytes memory quote1, uint256 sellAmount1) =
            getQuoteDataForMint(buyAmount1, components[1], inputToken);

        quotes[1] = quote1;

        uint256 amountWithSlippage = (sellAmount1 * 101 / 100);
        deal(inputToken, tradeIssuerAddress, amountWithSlippage); // Only required amount for the swap here
        uint256 inputTokenBalanceBefore = IERC20(inputToken).balanceOf(tradeIssuerAddress);

        vm.prank(tradeIssuerAddress);
        IERC20(inputToken).approve(zeroExProxy, type(uint256).max);

        uint256 inputTokensUsed = tradeIssuer.buyAssetsInDex(
            quotes, IERC20(inputToken), components, componentsQuantities, 5
        );

        uint256 component1BalanceAfter = IERC20(components[1]).balanceOf(tradeIssuerAddress);
        uint256 inputTokenBalanceAfter = IERC20(inputToken).balanceOf(tradeIssuerAddress);

        assertLe(
            component1BalanceAfter - component1BalanceBefore,
            (componentsQuantities[1] * 1005) / 1000
        );
        assertEq(
            buyAmountInputToken + inputTokenBalanceBefore - inputTokenBalanceAfter, inputTokensUsed
        );
    }
}
