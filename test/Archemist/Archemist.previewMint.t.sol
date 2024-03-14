// SPDX-License-Identifier: Apache License 2.0
pragma solidity ^0.8.24;

import { ArchemistTest } from "test/utils/ArchemistTest.sol";
import { IArchemist } from "src/interfaces/IArchemist.sol";

contract ArchemistPreviewMintTest is ArchemistTest {
    /*//////////////////////////////////////////////////////////////
                              REVERT
    //////////////////////////////////////////////////////////////*/

    /**
     * [ERROR] Should revert when previewing mint with zero amount.
     */
    function testCannotPreviewMintWithZeroAmount() public {
        vm.expectRevert(abi.encodeWithSelector(IArchemist.ZeroMintAmount.selector));
        archemist.previewMint(0);
    }

    /**
     * [ERROR] Should revert when previewing mint with zero price per share.
     */
    function testCannotPreviewMintWithZeroPricePerShare(uint128 randomMintAmount) public {
        vm.assume(randomMintAmount != 0);
        vm.expectRevert(abi.encodeWithSelector(IArchemist.ZeroPricePerShare.selector));
        archemist.previewMint(randomMintAmount);
    }

    /**
     * [ERROR] Should revert when previewing mint with insufficient exchange token balance.
     */
    function testCannotPreviewMintWithInsufficientExchangeTokenBalance() public {
        vm.prank(admin);
        archemist.updatePricePerShare(1 ether);

        vm.expectRevert(
            abi.encodeWithSelector(IArchemist.InsufficientExchangeTokenBalance.selector)
        );
        archemist.previewMint(1 ether);
    }

    /*//////////////////////////////////////////////////////////////
                              SUCCESS
    //////////////////////////////////////////////////////////////*/

    /**
     * [SUCCESS] Should calculate exchange amount when previewing mint with usdc as base token
     * and aedy as exchange token and random price and mint amounts.
     */
    function testPreviewMintWithUsdcAsBaseTokenAndAedyAsExchangeTokenAndRandomPriceAndMintAmounts(
        uint256 randomPricePerShare,
        uint256 randomMintAmount
    ) public {
        vm.assume(randomPricePerShare != 0);
        vm.assume(randomPricePerShare <= type(uint128).max);
        vm.assume(randomMintAmount != 0);
        vm.assume(randomMintAmount <= type(uint64).max);

        vm.prank(admin);
        archemist.updatePricePerShare(randomPricePerShare);

        uint256 baseTokenAmountWithoutChargingFees =
            (randomMintAmount * randomPricePerShare) / EIGHTEEN_DECIMALS;

        uint256 feePercentage = (exchangeFee * EIGHTEEN_DECIMALS) / 10000;

        uint256 expectedBaseTokenAmount = (baseTokenAmountWithoutChargingFees * EIGHTEEN_DECIMALS)
            / (EIGHTEEN_DECIMALS - feePercentage);

        deal(AEDY, address(archemist), randomMintAmount);

        uint256 baseTokenAmount = archemist.previewMint(randomMintAmount);

        assertEq(baseTokenAmount, expectedBaseTokenAmount);
        assertGe(baseTokenAmount, 0);
        assertEq(archemist.pricePerShare(), randomPricePerShare);
        assertEq(archemist.paused(), true);
    }

    /**
     * /**
     * [SUCCESS] Should calculate exchange amount when previewing mint with addy as base token
     * and aedy as exchange token and random price and mint amounts.
     */
    function testPreviewMintWithAddyAsBaseTokenAndAedyAsExchangeTokenAndRandomPriceAndMintAmounts(
        uint256 randomPricePerShare,
        uint256 randomMintAmount
    ) public {
        vm.assume(randomPricePerShare != 0);
        vm.assume(randomPricePerShare <= type(uint128).max);
        vm.assume(randomMintAmount != 0);
        vm.assume(randomMintAmount <= type(uint64).max);

        vm.prank(admin);
        archemistAedyAddy.updatePricePerShare(randomPricePerShare);

        uint256 baseTokenAmountWithoutChargingFees =
            (randomMintAmount * randomPricePerShare) / EIGHTEEN_DECIMALS;

        uint256 feePercentage = (exchangeFee * EIGHTEEN_DECIMALS) / 10000;

        uint256 expectedBaseTokenAmount = (baseTokenAmountWithoutChargingFees * EIGHTEEN_DECIMALS)
            / (EIGHTEEN_DECIMALS - feePercentage);

        deal(AEDY, address(archemistAedyAddy), randomMintAmount);

        uint256 baseTokenAmount = archemistAedyAddy.previewMint(randomMintAmount);

        assertEq(baseTokenAmount, expectedBaseTokenAmount);
        assertGe(baseTokenAmount, 0);
        assertEq(archemistAedyAddy.pricePerShare(), randomPricePerShare);
        assertEq(archemistAedyAddy.paused(), true);
    }

    /**
     * /**
     * [SUCCESS] Should calculate exchange amount when previewing mint with addy as base token
     * and usdc as exchange token and random price and mint amounts.
     */
    function testPreviewMintWithAddyAsBaseTokenAndUsdcExchangeTokenAndRandomPriceAndMintAmounts(
        uint256 randomPricePerShare,
        uint256 randomMintAmount
    ) public {
        vm.assume(randomPricePerShare != 0);
        vm.assume(randomPricePerShare <= type(uint128).max);
        vm.assume(randomMintAmount != 0);
        vm.assume(randomMintAmount <= type(uint64).max);

        vm.prank(admin);
        archemistAddyUsdc.updatePricePerShare(randomPricePerShare);

        uint256 baseTokenAmountWithoutChargingFees =
            (randomMintAmount * randomPricePerShare) / SIX_DECIMALS;

        uint256 feePercentage = (exchangeFee * SIX_DECIMALS) / 10000;

        uint256 expectedBaseTokenAmount =
            (baseTokenAmountWithoutChargingFees * SIX_DECIMALS) / (SIX_DECIMALS - feePercentage);

        deal(USDC, address(archemistAddyUsdc), randomMintAmount);

        uint256 baseTokenAmount = archemistAddyUsdc.previewMint(randomMintAmount);

        assertEq(baseTokenAmount, expectedBaseTokenAmount);
        assertGe(baseTokenAmount, 0);
        assertEq(archemistAddyUsdc.pricePerShare(), randomPricePerShare);
        assertEq(archemistAddyUsdc.paused(), true);
    }

    /**
     * [SUCCESS] Should calculate correct base token amount (fees considered) when previewing mint with usdc as base token
     * and addy as exchange with equal deposit amount and price per share.
     */
    function testPreviewMintWithUsdcAsBaseTokenAndAedyAsExchangeTokenAndEqualMintAmountAndPricePerShare(
    ) public {
        vm.prank(admin);
        archemist.updatePricePerShare(1 ether);

        deal(AEDY, address(archemist), 1 ether);

        uint256 baseTokenAmount = archemist.previewMint(1 ether);

        assertEq(baseTokenAmount, 1111111111111111111);
        assertGe(baseTokenAmount, 0);
        assertEq(archemist.pricePerShare(), 1 ether);
        assertEq(archemist.paused(), true);
    }

    /**
     * [SUCCESS] Should calculate correct base token amount (fees considered) when previewing mint with addy as base token
     * and aedy as exchange with equal deposit amount and price per share.
     */
    function testPreviewMintWithAddyAsBaseTokenAndAedyAsExchangeTokenAndEqualMintAmountAndPricePerShare(
    ) public {
        vm.prank(admin);
        archemistAedyAddy.updatePricePerShare(1 ether);

        deal(AEDY, address(archemistAedyAddy), 1 ether);

        uint256 baseTokenAmount = archemistAedyAddy.previewMint(1 ether);

        assertEq(baseTokenAmount, 1111111111111111111);
        assertGe(baseTokenAmount, 0);
        assertEq(archemistAedyAddy.pricePerShare(), 1 ether);
        assertEq(archemistAedyAddy.paused(), true);
    }

    /**
     * [SUCCESS] Should calculate correct base token amount (fees considered) when previewing mint with addy as base token
     * and usdc as exchange with equal deposit amount and price per share.
     */
    function testPreviewMintWithAddyAsBaseTokenAndUsdcAsExchangeTokenAndEqualMintAmountAndPricePerShare(
    ) public {
        vm.prank(admin);
        archemistAddyUsdc.updatePricePerShare(1e6);

        deal(USDC, address(archemistAddyUsdc), 1e6);

        uint256 baseTokenAmount = archemistAddyUsdc.previewMint(1e6);

        assertEq(baseTokenAmount, 1111111); // 1.111111 USDC
        assertGe(baseTokenAmount, 0);
        assertEq(archemistAddyUsdc.pricePerShare(), 1e6);
        assertEq(archemistAddyUsdc.paused(), true);
    }
}
