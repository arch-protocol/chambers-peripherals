// SPDX-License-Identifier: Apache License 2.0
pragma solidity ^0.8.24;

import { ArchemistTest } from "test/utils/ArchemistTest.sol";
import { IArchemist } from "src/interfaces/IArchemist.sol";

contract ArchemistPreviewRedeemTest is ArchemistTest {
    /*//////////////////////////////////////////////////////////////
                              REVERT
    //////////////////////////////////////////////////////////////*/

    /**
     * [ERROR] Should revert when previewing redeem with zero amount.
     */
    function testCannotPreviewRedeemWithZeroAmount() public {
        vm.expectRevert(abi.encodeWithSelector(IArchemist.ZeroRedeemAmount.selector));
        archemist.previewRedeem(0);
    }

    /**
     * [ERROR] Should revert when previewing redeem with zero price per share.
     */
    function testCannotPreviewRedeemWithZeroPricePerShare(uint128 randomBaseTokenAmount) public {
        vm.assume(randomBaseTokenAmount != 0);
        vm.expectRevert(abi.encodeWithSelector(IArchemist.ZeroPricePerShare.selector));
        archemist.previewRedeem(randomBaseTokenAmount);
    }

    /**
     * [ERROR] Should revert when previewing redeem with insufficient base token balance.
     */
    function testCannotPreviewRedeemWithInsufficientBaseTokenBalance() public {
        vm.prank(admin);
        archemist.updatePricePerShare(1 ether);

        vm.expectRevert(abi.encodeWithSelector(IArchemist.InsufficientBaseTokenBalance.selector));
        archemist.previewRedeem(1 ether);
    }

    /*//////////////////////////////////////////////////////////////
                                  SUCCESS
        //////////////////////////////////////////////////////////////*/

    /**
     * [SUCCESS] Should calculate base token amount when previewing redeem with usdc as base token
     * and aedy as exchange token and random price and base token amounts.
     */
    function testPreviewRedeemWithUsdcAsBaseTokenAndAedyAsExchangeTokenAndRandomPriceAndBaseTokenAmounts(
        uint128 randomPricePerShare,
        uint128 randomBaseTokenAmount
    ) public {
        vm.assume(randomPricePerShare != 0);
        vm.assume(randomBaseTokenAmount != 0);
        vm.assume(randomBaseTokenAmount <= type(uint64).max);

        vm.prank(admin);
        archemist.updatePricePerShare(randomPricePerShare);

        uint256 expectedExchangeTokenAmountWithoutFees =
            (randomBaseTokenAmount * EIGHTEEN_DECIMALS) / randomPricePerShare;

        uint256 feePercentage = (exchangeFee * EIGHTEEN_DECIMALS) / 10000;

        uint256 expectedExchangeTokenAmount = (
            expectedExchangeTokenAmountWithoutFees * EIGHTEEN_DECIMALS
        ) / (EIGHTEEN_DECIMALS - feePercentage);

        deal(USDC, address(archemist), randomBaseTokenAmount);

        uint256 exchangeTokenAmount = archemist.previewRedeem(randomBaseTokenAmount);

        assertEq(exchangeTokenAmount, expectedExchangeTokenAmount);
        assertGe(exchangeTokenAmount, 0);
        assertEq(archemist.pricePerShare(), randomPricePerShare);
        assertEq(archemist.paused(), true);
    }

    /**
     * [SUCCESS] Should calculate exchange token amount when previewing redeem with addy as base token
     * and aedy as exchange token and random price and base token amounts.
     */
    function testPreviewRedeemWithAddyAsBaseTokenAndAedyAsExchangeTokenAndRandomPriceAndBaseTokenAmounts(
        uint128 randomPricePerShare,
        uint128 randomBaseTokenAmount
    ) public {
        vm.assume(randomPricePerShare != 0);
        vm.assume(randomBaseTokenAmount != 0);
        vm.assume(randomBaseTokenAmount <= type(uint64).max);

        vm.prank(admin);
        archemistAedyAddy.updatePricePerShare(randomPricePerShare);

        uint256 expectedExchangeTokenAmountWithoutFees =
            (randomBaseTokenAmount * EIGHTEEN_DECIMALS) / randomPricePerShare;

        uint256 feePercentage = (exchangeFee * EIGHTEEN_DECIMALS) / 10000;

        uint256 expectedExchangeTokenAmount = (
            expectedExchangeTokenAmountWithoutFees * EIGHTEEN_DECIMALS
        ) / (EIGHTEEN_DECIMALS - feePercentage);

        deal(ADDY, address(archemistAedyAddy), randomBaseTokenAmount);

        uint256 exchangeTokenAmount = archemistAedyAddy.previewRedeem(randomBaseTokenAmount);

        assertEq(exchangeTokenAmount, expectedExchangeTokenAmount);
        assertGe(exchangeTokenAmount, 0);
        assertEq(archemistAedyAddy.pricePerShare(), randomPricePerShare);
        assertEq(archemistAedyAddy.paused(), true);
    }

    /**
     * [SUCCESS] Should calculate exchange token amount when previewing redeem with addy as base token
     * and usdc as exchange token and random price and base token amounts.
     */
    function testPreviewRedeemWithAddyAsBaseTokenAndUsdcAsExchangeTokenAndRandomPriceAndBaseTokenAmounts(
        uint128 randomPricePerShare,
        uint128 randomBaseTokenAmount
    ) public {
        vm.assume(randomPricePerShare != 0);
        vm.assume(randomBaseTokenAmount != 0);
        vm.assume(randomBaseTokenAmount <= type(uint64).max);

        vm.prank(admin);
        archemistAddyUsdc.updatePricePerShare(randomPricePerShare);

        uint256 expectedExchangeTokenAmountWithoutFees =
            (randomBaseTokenAmount * SIX_DECIMALS) / randomPricePerShare;

        uint256 feePercentage = (exchangeFee * SIX_DECIMALS) / 10000;

        uint256 expectedExchangeTokenAmount =
            (expectedExchangeTokenAmountWithoutFees * SIX_DECIMALS) / (SIX_DECIMALS - feePercentage);

        deal(ADDY, address(archemistAddyUsdc), randomBaseTokenAmount);

        uint256 exchangeTokenAmount = archemistAddyUsdc.previewRedeem(randomBaseTokenAmount);

        assertEq(exchangeTokenAmount, expectedExchangeTokenAmount);
        assertGe(exchangeTokenAmount, 0);
        assertEq(archemistAddyUsdc.pricePerShare(), randomPricePerShare);
        assertEq(archemistAddyUsdc.paused(), true);
    }

    /**
     * [SUCCESS] Should calculate correct exchange token amount (fees considered) when previewing redeem with usdc as base token
     * and addy as exchange with equal deposit amount and price per share.
     */
    function testPreviewRedeemWithUsdcAsBaseTokenAndAedyAsExchangeTokenAndEqualRedeemAmountAndPricePerShare(
    ) public {
        vm.prank(admin);
        archemist.updatePricePerShare(1 ether);

        deal(USDC, address(archemist), 1 ether);

        uint256 exchangeTokenAmount = archemist.previewRedeem(1 ether);

        assertEq(exchangeTokenAmount, 1111111111111111111);
        assertGe(exchangeTokenAmount, 0);
        assertEq(archemist.pricePerShare(), 1 ether);
        assertEq(archemist.paused(), true);
    }

    /**
     * [SUCCESS] Should calculate correct exchange token amount (fees considered) when previewing redeem with addy as base token
     * and aedy as exchange with equal deposit amount and price per share.
     */
    function testPreviewRedeemWithAddyAsBaseTokenAndAedyAsExchangeTokenAndEqualDepositAmountAndPricePerShare(
    ) public {
        vm.prank(admin);
        archemistAedyAddy.updatePricePerShare(1 ether);

        deal(ADDY, address(archemistAedyAddy), 1 ether);

        uint256 exchangeTokenAmount = archemistAedyAddy.previewRedeem(1 ether);

        assertEq(exchangeTokenAmount, 1111111111111111111);
        assertGe(exchangeTokenAmount, 0);
        assertEq(archemistAedyAddy.pricePerShare(), 1 ether);
        assertEq(archemistAedyAddy.paused(), true);
    }

    /**
     * [SUCCESS] Should calculate correct exchange token amount (fees considered) when previewing redeem with addy as base token
     * and usdc as exchange with equal deposit amount and price per share.
     */
    function testPreviewRedeemWithAddyAsBaseTokenAndUsdcAsExchangeTokenAndEqualDepositAmountAndPricePerShare(
    ) public {
        vm.prank(admin);
        archemistAddyUsdc.updatePricePerShare(1 ether);

        deal(ADDY, address(archemistAddyUsdc), 1 ether);

        uint256 exchangeTokenAmount = archemistAddyUsdc.previewRedeem(1 ether);

        assertEq(exchangeTokenAmount, 1111111); // 1.111111 USDC
        assertGe(exchangeTokenAmount, 0);
        assertEq(archemistAddyUsdc.pricePerShare(), 1 ether);
        assertEq(archemistAddyUsdc.paused(), true);
    }
}
