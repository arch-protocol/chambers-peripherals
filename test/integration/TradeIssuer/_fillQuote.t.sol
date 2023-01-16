// Copyright 2022 Smash Works Inc.
// SPDX-License-Identifier: Apache License 2.0
pragma solidity ^0.8.17.0;

import {ChamberTestUtils} from "test/utils/ChamberTestUtils.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ExposedTradeIssuer} from "test/utils/ExposedTradeIssuer.sol";

contract TradeIssuerIntegrationInternalFillQuoteTest is ChamberTestUtils {
    using SafeERC20 for IERC20;

    /*//////////////////////////////////////////////////////////////
                              VARIABLES
    //////////////////////////////////////////////////////////////*/

    ExposedTradeIssuer public tradeIssuer;
    address public tradeIssuerAddress;
    address payable public zeroExProxy = payable(0xDef1C0ded9bec7F1a1670819833240f027b25EfF); //0x on ETH
    address public wETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2; // WETH on ETH
    address public inputToken = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48; // USDC on ETH

    /*//////////////////////////////////////////////////////////////
                              SET UP
    //////////////////////////////////////////////////////////////*/

    function setUp() public {
        tradeIssuer = new ExposedTradeIssuer(zeroExProxy, wETH);
        tradeIssuerAddress = address(tradeIssuer);
        vm.label(tradeIssuerAddress, "TradeIssuer");
    }

    /*//////////////////////////////////////////////////////////////
                              REVERT
    //////////////////////////////////////////////////////////////*/

    /**
     * [REVERT] Should revert because tradeIssuer has balance but no approve has been granted on
     * the input token. Fuzz values between 10 USDC and 1.000.000 USDC to swap with WETH.
     */
    function testCannotSwapWithoutInputTokenApproveOnTradeIssuer(uint256 buyAmount) public {
        vm.assume(buyAmount > 1 ether);
        vm.assume(buyAmount < 1000 ether);

        (bytes memory quote, uint256 sellAmount) = getQuoteDataForMint(buyAmount, wETH, inputToken);
        uint256 amountWithSlippage = (sellAmount * 101 / 100);

        deal(inputToken, tradeIssuerAddress, amountWithSlippage);
        // Approve expected [here]

        vm.expectRevert();
        tradeIssuer.fillQuote(quote);

        assertEq(IERC20(inputToken).balanceOf(tradeIssuerAddress), amountWithSlippage);
    }

    /**
     * [REVERT] Should revert because tradeIssuer has no balance.
     * Fuzz values between 10 USDC and 1.000.000 USDC to swap with WETH.
     */
    function testCannotSwapWithoutInputTokenBalanceOnTradeIssuer(uint256 buyAmount) public {
        vm.assume(buyAmount > 1 ether);
        vm.assume(buyAmount < 1000 ether);

        (bytes memory quote,) = getQuoteDataForMint(buyAmount, wETH, inputToken);

        vm.prank(tradeIssuerAddress);
        IERC20(inputToken).approve(zeroExProxy, type(uint256).max);

        vm.expectRevert();
        tradeIssuer.fillQuote(quote);

        assertEq(IERC20(inputToken).balanceOf(tradeIssuerAddress), 0);
    }

    /**
     * [REVERT] Should revert with bad quotes call data.
     */
    function testCannotSwapWithBadQuotes() public {
        bytes memory quote = bytes("0x0123456");

        vm.expectRevert();
        tradeIssuer.fillQuote(quote);
    }

    /*//////////////////////////////////////////////////////////////
                              SUCCESS
    //////////////////////////////////////////////////////////////*/

    /**
     * [SUCCESS] Should call with correct quotes and swap successfully with 1% slippage.
     * Fuzz values between 10 USDC and 1.000.000 USDC to swap with WETH.
     */
    function testSuccessSwap(uint256 buyAmount) public {
        vm.assume(buyAmount > 1 ether);
        vm.assume(buyAmount < 1000 ether);

        (bytes memory quote, uint256 sellAmount) = getQuoteDataForMint(buyAmount, wETH, inputToken);

        uint256 amountWithSlippage = (sellAmount * 101 / 100);
        deal(inputToken, tradeIssuerAddress, amountWithSlippage);

        vm.prank(tradeIssuerAddress);
        IERC20(inputToken).approve(zeroExProxy, type(uint256).max);

        bytes memory responseCall = tradeIssuer.fillQuote(quote);

        uint256 amountBought = abi.decode(responseCall, (uint256));
        uint256 inputTokenBalanceAfter = IERC20(inputToken).balanceOf(tradeIssuerAddress);

        assertGe(sellAmount * 1 / 100, inputTokenBalanceAfter);
        assertApproxEqAbs(
            buyAmount, IERC20(wETH).balanceOf(tradeIssuerAddress), buyAmount * 5 / 1000
        );
        assertEq(IERC20(wETH).balanceOf(tradeIssuerAddress), amountBought);
    }
}
