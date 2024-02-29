// SPDX-License-Identifier: Apache License 2.0
pragma solidity ^0.8.24;

import { ArchemistTest } from "test/utils/ArchemistTest.sol";
import { IArchemist } from "src/interfaces/IArchemist.sol";

contract ArchemistPreviewWithdrawTest is ArchemistTest {
    /*//////////////////////////////////////////////////////////////
                              REVERT
    //////////////////////////////////////////////////////////////*/

    /**
     * [ERROR] Should revert when previewing withdraw with zero amount.
     */
    function testCannotPreviewWithdrawWithZeroAmount() public {
        vm.expectRevert(abi.encodeWithSelector(IArchemist.ZeroWithdrawAmount.selector));
        archemist.previewWithdraw(0);
    }

    /**
     * [ERROR] Should revert when previewing withdraw with zero price per share.
     */
    function testCannotPreviewWithdrawWithZeroPricePerShare(uint128 randomWithdrawAmount) public {
        vm.assume(randomWithdrawAmount != 0);
        vm.expectRevert(abi.encodeWithSelector(IArchemist.ZeroPricePerShare.selector));
        archemist.previewWithdraw(randomWithdrawAmount);
    }

    /*//////////////////////////////////////////////////////////////
                              SUCCESS
    //////////////////////////////////////////////////////////////*/

    /**
     * [SUCCESS] Should calculate base token amount when previewing withdraw with usdc as base token
     * and aedy as exchange token and random price and withdraw amounts.
     */
    function testPreviewWithdrawWithUsdcAsBaseTokenAndAedyAsExchangeTokenAndRandomPriceAndWithdrawAmounts(
        uint256 randomPricePerShare,
        uint256 randomWithdrawAmount
    ) public {
        vm.assume(randomPricePerShare != 0);
        vm.assume(randomPricePerShare <= type(uint128).max);
        vm.assume(randomWithdrawAmount != 0);
        vm.assume(randomWithdrawAmount <= type(uint64).max);

        vm.prank(admin);
        archemist.updatePricePerShare(randomPricePerShare);

        uint256 baseTokenAmount = archemist.previewWithdraw(randomWithdrawAmount);

        uint256 baseTokenAmountWithoutChargingFees =
            (randomWithdrawAmount * randomPricePerShare) / 10 ** 18;

        uint256 feeAmount = (baseTokenAmountWithoutChargingFees * exchangeFee) / 10000;

        uint256 expectedWithdrawAmount = baseTokenAmountWithoutChargingFees - feeAmount;

        assertEq(baseTokenAmount, expectedWithdrawAmount);
        assertGe(baseTokenAmount, 0);
        assertEq(archemist.pricePerShare(), randomPricePerShare);
        assertEq(archemist.paused(), true);
    }

    /**
     * [SUCCESS] Should calculate base token amount when previewing withdraw with addy as base token
     * and aedy as exchange token and random price and withdraw amounts.
     */
    function testPreviewWithdrawWithAddyAsBaseTokenAndAedyAsExchangeTokenAndRandomPriceAndWithdrawAmounts(
        uint256 randomPricePerShare,
        uint256 randomWithdrawAmount
    ) public {
        vm.assume(randomPricePerShare != 0);
        vm.assume(randomPricePerShare <= type(uint128).max);
        vm.assume(randomWithdrawAmount != 0);
        vm.assume(randomWithdrawAmount <= type(uint64).max);

        vm.prank(admin);
        archemistAedyAddy.updatePricePerShare(randomPricePerShare);

        uint256 baseTokenAmount = archemistAedyAddy.previewWithdraw(randomWithdrawAmount);

        uint256 baseTokenAmountWithoutChargingFees =
            (randomWithdrawAmount * randomPricePerShare) / 10 ** 18;

        uint256 feeAmount = (baseTokenAmountWithoutChargingFees * exchangeFee) / 10000;

        uint256 expectedWithdrawAmount = baseTokenAmountWithoutChargingFees - feeAmount;

        assertEq(baseTokenAmount, expectedWithdrawAmount);
        assertGe(baseTokenAmount, 0);
        assertEq(archemistAedyAddy.pricePerShare(), randomPricePerShare);
        assertEq(archemistAedyAddy.paused(), true);
    }

    /**
     * [SUCCESS] Should calculate base token amount when previewing withdraw with addy as base token
     * and usdc as exchange token and random price and withdraw amounts.
     */
    function testPreviewWithdrawWithAddyAsBaseTokenAndUsdcAsExchangeTokenAndRandomPriceAndWithdrawAmounts(
        uint256 randomPricePerShare,
        uint256 randomWithdrawAmount
    ) public {
        vm.assume(randomPricePerShare != 0);
        vm.assume(randomPricePerShare <= type(uint128).max);
        vm.assume(randomWithdrawAmount != 0);
        vm.assume(randomWithdrawAmount <= type(uint64).max);

        vm.prank(admin);
        archemistAddyUsdc.updatePricePerShare(randomPricePerShare);

        uint256 baseTokenAmount = archemistAddyUsdc.previewWithdraw(randomWithdrawAmount);

        uint256 baseTokenAmountWithoutChargingFees =
            (randomWithdrawAmount * randomPricePerShare) / 10 ** 6;

        uint256 feeAmount = (baseTokenAmountWithoutChargingFees * exchangeFee) / 10000;

        uint256 expectedWithdrawAmount = baseTokenAmountWithoutChargingFees - feeAmount;

        assertEq(baseTokenAmount, expectedWithdrawAmount);
        assertGe(baseTokenAmount, 0);
        assertEq(archemistAddyUsdc.pricePerShare(), randomPricePerShare);
        assertEq(archemistAddyUsdc.paused(), true);
    }

    /**
     * [SUCCESS] Should calculate base token amount when previewing withdraw with usdc as base token
     * and addy as exchange token and fixed amounts.
     */
    function testPreviewWithdrawWithUsdcAsBaseTokenAndAddyAsExchangeTokenAndFixedAmounts() public {
        vm.prank(admin);
        archemist.updatePricePerShare(1e6);

        uint256 baseTokenAmount = archemist.previewWithdraw(1 ether);

        assertEq(baseTokenAmount, 9e5);
        assertEq(archemist.pricePerShare(), 1e6);
        assertEq(archemist.paused(), true);
    }

    /**
     * [SUCCESS] Should calculate base token amount when previewing withdraw with addy as base token
     * and aedy as exchange token and fixed amounts.
     */
    function testPreviewWithdrawWithAddyAsBaseTokenAndAedyAsExchangeTokenAndFixedAmounts() public {
        vm.prank(admin);
        archemistAedyAddy.updatePricePerShare(1 ether);

        uint256 baseTokenAmount = archemistAedyAddy.previewWithdraw(1 ether);

        assertEq(baseTokenAmount, 0.9 ether);
        assertEq(archemistAedyAddy.pricePerShare(), 1 ether);
        assertEq(archemistAedyAddy.paused(), true);
    }

    /**
     * [SUCCESS] Should calculate base token amount when previewing withdraw with aedy as base token
     * and usdc as exchange token and fixed amounts.
     */
    function testPreviewWithdrawWithAddyAsBaseTokenAndUsdcAsExchangeTokenAndFixedAmounts() public {
        vm.prank(admin);
        archemistAddyUsdc.updatePricePerShare(1 ether);

        uint256 baseTokenAmount = archemistAddyUsdc.previewWithdraw(1e6);

        assertEq(baseTokenAmount, 0.9 ether);
        assertEq(archemistAddyUsdc.pricePerShare(), 1 ether);
        assertEq(archemistAddyUsdc.paused(), true);
    }
}
