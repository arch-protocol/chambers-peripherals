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

        uint256 baseTokenAmount = archemist.previewMint(randomMintAmount);

        uint256 baseTokenAmountWithoutChargingFees =
            (randomMintAmount * randomPricePerShare) / 10 ** 18;

        uint256 feePercentage = exchangeFee / 10000;

        uint256 expectedBaseTokenAmount = baseTokenAmountWithoutChargingFees / (1 - feePercentage);

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

        uint256 baseTokenAmount = archemistAedyAddy.previewMint(randomMintAmount);

        uint256 baseTokenAmountWithoutChargingFees =
            (randomMintAmount * randomPricePerShare) / 10 ** 18;

        uint256 feePercentage = exchangeFee / 10000;

        uint256 expectedBaseTokenAmount = baseTokenAmountWithoutChargingFees / (1 - feePercentage);

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
    function testPreviewMintWithAddyAsBaseTokenAndAedyAsExchangeTokenAndRandomPriceAndMintAmounts(
        uint256 randomPricePerShare,
        uint256 randomMintAmount
    ) public {
        vm.assume(randomPricePerShare != 0);
        vm.assume(randomPricePerShare <= type(uint128).max);
        vm.assume(randomMintAmount != 0);
        vm.assume(randomMintAmount <= type(uint64).max);

        vm.prank(admin);
        archemistAddyUsdc.updatePricePerShare(randomPricePerShare);

        uint256 baseTokenAmount = archemistAddyUsdc.previewMint(randomMintAmount);

        uint256 baseTokenAmountWithoutChargingFees =
            (randomMintAmount * randomPricePerShare) / 10 ** 18;

        uint256 feePercentage = exchangeFee / 10000;

        uint256 expectedBaseTokenAmount = baseTokenAmountWithoutChargingFees / (1 - feePercentage);

        assertEq(baseTokenAmount, expectedBaseTokenAmount);
        assertGe(baseTokenAmount, 0);
        assertEq(archemistAddyUsdc.pricePerShare(), randomPricePerShare);
        assertEq(archemistAddyUsdc.paused(), true);
    }
}
