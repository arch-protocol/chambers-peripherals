// SPDX-License-Identifier: Apache License 2.0
pragma solidity ^0.8.24;

import { ArchemistTest } from "test/utils/ArchemistTest.sol";
import { IArchemist } from "src/interfaces/IArchemist.sol";

contract ArchemistPreviewDepositTest is ArchemistTest {
    /*//////////////////////////////////////////////////////////////
                              REVERT
    //////////////////////////////////////////////////////////////*/

    /**
     * [ERROR] Should revert when previewing deposit with zero amount.
     */
    function testCannotPreviewDepositWithZeroAmount() public {
        vm.expectRevert(abi.encodeWithSelector(IArchemist.ZeroDepositAmount.selector));
        archemist.previewDeposit(0);
    }

    /**
     * [ERROR] Should revert when previewing deposit with zero price per share.
     */
    function testCannotPreviewDepositWithZeroPricePerShare(uint128 randomDepositAmount) public {
        vm.assume(randomDepositAmount != 0);
        vm.expectRevert(abi.encodeWithSelector(IArchemist.ZeroPricePerShare.selector));
        archemist.previewDeposit(randomDepositAmount);
    }

    /**
     * [ERROR] Should revert when previewing deposit with insufficient exchange token balance.
     */
    function testCannotPreviewDepositWithInsufficientExchangeTokenBalance() public {
        vm.prank(admin);
        archemist.updatePricePerShare(1 ether);

        vm.expectRevert(
            abi.encodeWithSelector(IArchemist.InsufficientExchangeTokenBalance.selector)
        );
        archemist.previewDeposit(2 ether);
    }

    /*//////////////////////////////////////////////////////////////
                              SUCCESS
    //////////////////////////////////////////////////////////////*/

    /**
     * [SUCCESS] Should calculate exchange token amount when previewing deposit with usdc as base token
     * and aedy as exchange token and random price and deposit amounts.
     */
    function testPreviewDepositWithUsdcAsBaseTokenAndAedyAsExchangeTokenAndRandomPriceAndDepositAmounts(
        uint128 randomPricePerShare,
        uint128 randomDepositAmount
    ) public {
        vm.assume(randomPricePerShare != 0);
        vm.assume(randomDepositAmount != 0);
        vm.assume(randomDepositAmount <= type(uint64).max);

        vm.prank(admin);
        archemist.updatePricePerShare(randomPricePerShare);

        uint256 feeAmount = (randomDepositAmount * exchangeFee) / 10000;

        uint256 depositAmount = randomDepositAmount - feeAmount;

        uint256 expectedExchangeTokenAmount = (depositAmount * 10 ** 18) / randomPricePerShare;

        deal(AEDY, address(archemist), expectedExchangeTokenAmount);

        uint256 exchangeTokenAmount = archemist.previewDeposit(randomDepositAmount);

        assertEq(exchangeTokenAmount, expectedExchangeTokenAmount);
        assertGe(exchangeTokenAmount, 0);
        assertEq(archemist.pricePerShare(), randomPricePerShare);
        assertEq(archemist.paused(), true);
    }

    /**
     * [SUCCESS] Should calculate exchange token amount when previewing deposit with addy as base token
     * and aedy as exchange token and random price and deposit amounts.
     */
    function testPreviewDepositWithAddyAsBaseTokenAndAedyAsExchangeTokenAndRandomPriceAndDepositAmounts(
        uint128 randomPricePerShare,
        uint128 randomDepositAmount
    ) public {
        vm.assume(randomPricePerShare != 0);
        vm.assume(randomDepositAmount != 0);
        vm.assume(randomDepositAmount <= type(uint64).max);

        vm.prank(admin);
        archemistAedyAddy.updatePricePerShare(randomPricePerShare);

        uint256 feeAmount = (randomDepositAmount * exchangeFee) / 10000;

        uint256 depositAmount = randomDepositAmount - feeAmount;

        uint256 expectedExchangeTokenAmount = (depositAmount * 10 ** 18) / randomPricePerShare;

        deal(AEDY, address(archemistAedyAddy), expectedExchangeTokenAmount);

        uint256 exchangeTokenAmount = archemistAedyAddy.previewDeposit(randomDepositAmount);

        assertEq(exchangeTokenAmount, expectedExchangeTokenAmount);
        assertGe(exchangeTokenAmount, 0);
        assertEq(archemistAedyAddy.pricePerShare(), randomPricePerShare);
        assertEq(archemistAedyAddy.paused(), true);
    }

    /**
     * [SUCCESS] Should calculate exchange token amount when previewing deposit with addy as base token
     * and usdc as exchange token and random price and deposit amounts.
     */
    function testPreviewDepositWithAddyAsBaseTokenAndUsdcAsExchangeTokenAndRandomPriceAndDepositAmounts(
        uint128 randomPricePerShare,
        uint128 randomDepositAmount
    ) public {
        vm.assume(randomPricePerShare != 0);
        vm.assume(randomDepositAmount != 0);
        vm.assume(randomDepositAmount <= type(uint64).max);

        vm.prank(admin);
        archemistAddyUsdc.updatePricePerShare(randomPricePerShare);

        uint256 feeAmount = (randomDepositAmount * exchangeFee) / 10000;

        uint256 depositAmount = randomDepositAmount - feeAmount;

        uint256 expectedExchangeTokenAmount = (depositAmount * 10 ** 6) / randomPricePerShare;

        deal(USDC, address(archemistAddyUsdc), expectedExchangeTokenAmount);

        uint256 exchangeTokenAmount = archemistAddyUsdc.previewDeposit(randomDepositAmount);

        assertEq(exchangeTokenAmount, expectedExchangeTokenAmount);
        assertGe(exchangeTokenAmount, 0);
        assertEq(archemistAddyUsdc.pricePerShare(), randomPricePerShare);
        assertEq(archemistAddyUsdc.paused(), true);
    }

    /**
     * [SUCCESS] Should calculate exchange token amount equals to 0.9 (fees considered) ether when previewing deposit with usdc as base token
     * and addy as exchange with equal deposit amount and price per share.
     */
    function testPreviewDepositWithUsdcAsBaseTokenAndAedyAsExchangeTokenAndEqualDepositAmountAndPricePerShare(
    ) public {
        vm.prank(admin);
        archemist.updatePricePerShare(1 ether);

        deal(AEDY, address(archemist), 0.9 ether);

        uint256 exchangeTokenAmount = archemist.previewDeposit(1 ether);

        assertEq(exchangeTokenAmount, 0.9 ether);
        assertGe(exchangeTokenAmount, 0);
        assertEq(archemist.pricePerShare(), 1 ether);
        assertEq(archemist.paused(), true);
    }

    /**
     * [SUCCESS] Should calculate exchange token amount equals to 0.9 (fees considered) ether when previewing deposit with addy as base token
     * and aedy as exchange with equal deposit amount and price per share.
     */
    function testPreviewDepositWithAddyAsBaseTokenAndAedyAsExchangeTokenAndEqualDepositAmountAndPricePerShare(
    ) public {
        vm.prank(admin);
        archemistAedyAddy.updatePricePerShare(1 ether);

        deal(AEDY, address(archemistAedyAddy), 0.9 ether);

        uint256 exchangeTokenAmount = archemistAedyAddy.previewDeposit(1 ether);

        assertEq(exchangeTokenAmount, 0.9 ether);
        assertGe(exchangeTokenAmount, 0);
        assertEq(archemistAedyAddy.pricePerShare(), 1 ether);
        assertEq(archemistAedyAddy.paused(), true);
    }

    /**
     * [SUCCESS] Should calculate exchange token amount equals to 0.9 (fees considered) ether when previewing deposit with addy as base token
     * and usdc as exchange with equal deposit amount and price per share.
     */
    function testPreviewDepositWithAddyAsBaseTokenAndUsdcAsExchangeTokenAndEqualDepositAmountAndPricePerShare(
    ) public {
        vm.prank(admin);
        archemistAddyUsdc.updatePricePerShare(1 ether);

        deal(USDC, address(archemistAddyUsdc), 9e5);

        uint256 exchangeTokenAmount = archemistAddyUsdc.previewDeposit(1 ether);

        assertEq(exchangeTokenAmount, 9e5); // 0.9 USDC
        assertGe(exchangeTokenAmount, 0);
        assertEq(archemistAddyUsdc.pricePerShare(), 1 ether);
        assertEq(archemistAddyUsdc.paused(), true);
    }
}
