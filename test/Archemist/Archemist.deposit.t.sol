// SPDX-License-Identifier: Apache License 2.0
pragma solidity ^0.8.24;

import { ArchemistTest } from "test/utils/ArchemistTest.sol";
import { IArchemist } from "src/interfaces/IArchemist.sol";
import { Pausable } from "@openzeppelin/contracts/utils/Pausable.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract ArchemistDepositTest is ArchemistTest {
    /*//////////////////////////////////////////////////////////////
                              REVERT
    //////////////////////////////////////////////////////////////*/

    /**
     * [ERROR] Should revert when deposit with zero amount.
     */
    function testCannotDepositWithZeroDepositAmount() public {
        vm.prank(admin);
        archemist.unpause();
        vm.expectRevert(abi.encodeWithSelector(IArchemist.ZeroDepositAmount.selector));
        archemist.deposit(0);
    }

    /**
     * [ERROR] Should revert when deposit with zero price per share.
     */
    function testCannotDepositWithZeroPricePerShare(uint128 randomDepositAmount) public {
        vm.prank(admin);
        archemist.unpause();
        vm.assume(randomDepositAmount != 0);
        vm.expectRevert(abi.encodeWithSelector(IArchemist.ZeroPricePerShare.selector));
        archemist.deposit(randomDepositAmount);
    }

    /**
     * [ERROR] Should revert when deposit is called and contract is paused
     */
    function testCannotDepositWhenContractIsPaused(uint128 randomDepositAmount) public {
        vm.expectRevert(abi.encodeWithSelector(Pausable.EnforcedPause.selector));
        archemist.deposit(randomDepositAmount);
    }
    /**
     * [ERROR] Should revert if there's no balance at the user
     */

    function testCannotDepositIfUserHasNoBalance(
        uint128 randomPricePerShare,
        uint128 randomDepositAmount
    ) public {
        vm.assume(randomPricePerShare != 0);
        vm.assume(randomDepositAmount != 0);
        vm.assume(randomDepositAmount <= type(uint64).max);

        vm.startPrank(admin);
        archemist.updatePricePerShare(randomPricePerShare);
        archemist.unpause();
        vm.stopPrank();

        vm.expectRevert("ERC20: transfer amount exceeds balance");
        vm.prank(ALICE);
        archemist.deposit(randomDepositAmount);
    }

    /**
     * [ERROR] Should revert if there's no allowance at the user
     */
    function testCannotDepositIfUserHasNoAllowance(
        uint128 randomPricePerShare,
        uint128 randomDepositAmount
    ) public {
        vm.assume(randomPricePerShare != 0);
        vm.assume(randomDepositAmount != 0);
        vm.assume(randomDepositAmount <= type(uint64).max);

        vm.startPrank(admin);
        archemist.updatePricePerShare(randomPricePerShare);
        archemist.unpause();
        vm.stopPrank();

        vm.expectRevert("ERC20: transfer amount exceeds balance");
        vm.prank(ALICE);
        archemist.deposit(randomDepositAmount);
    }

    /**
     * [ERROR] Should revert if there's no balance at the contract
     */
    function testCannotDepositIfContractHasNoBalance(
        uint128 randomPricePerShare,
        uint128 randomDepositAmount
    ) public {
        vm.assume(randomPricePerShare != 0);
        vm.assume(randomDepositAmount != 0);
        vm.assume(randomDepositAmount >= randomPricePerShare);
        vm.assume(randomDepositAmount <= type(uint64).max);

        vm.startPrank(admin);
        archemist.updatePricePerShare(randomPricePerShare);
        archemist.unpause();
        vm.stopPrank();

        deal(USDC, ALICE, randomDepositAmount);


        vm.startPrank(ALICE);
        ERC20(USDC).approve(address(archemist), randomDepositAmount);
        
        vm.expectRevert("ERC20: transfer amount exceeds balance");
        
        archemist.deposit(randomDepositAmount);
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                              SUCCESS
    //////////////////////////////////////////////////////////////*/

    /**
     * [SUCCESS] Should execute a deposit with usdc as base token
     * and aedy as exchange token and random price and deposit amounts.
     */
    function testDepositWithUsdcAsBaseTokenAndAedyAsExchangeTokenAndRandomPriceAndDepositAmounts(
        uint128 randomPricePerShare,
        uint128 randomDepositAmount
    ) public {
        vm.assume(randomPricePerShare != 0);
        vm.assume(randomDepositAmount != 0);
        vm.assume(randomDepositAmount <= type(uint64).max);

        deal(USDC, ALICE, randomDepositAmount);

        vm.startPrank(admin);
        archemist.updatePricePerShare(randomPricePerShare);
        archemist.unpause();
        vm.stopPrank();

        uint256 feeAmount = (randomDepositAmount * exchangeFee) / 10000;

        uint256 depositAmount = randomDepositAmount - feeAmount;

        uint256 expectedExchangeAmount = (depositAmount * 10 ** 18) / randomPricePerShare;

        deal(AEDY, address(archemist), expectedExchangeAmount);

        vm.startPrank(ALICE);
        ERC20(USDC).approve(address(archemist), randomDepositAmount);
        uint256 exchangeTokenAmount = archemist.deposit(randomDepositAmount);
        vm.stopPrank();

        assertEq(ERC20(USDC).balanceOf(address(archemist)), randomDepositAmount);
        assertEq(ERC20(USDC).balanceOf(ALICE), 0);
        assertEq(ERC20(AEDY).balanceOf(ALICE), expectedExchangeAmount);
        assertEq(ERC20(AEDY).balanceOf(address(archemist)), 0);
        assertEq(exchangeTokenAmount, expectedExchangeAmount);
        assertGe(exchangeTokenAmount, 0);
        assertEq(archemist.pricePerShare(), randomPricePerShare);
        assertEq(archemist.paused(), false);
    }

    /**
     * [SUCCESS] Should execute a deposit with addy as base token
     * and aedy as exchange token and random price and deposit amounts.
     */
    function testDepositWithAddyAsBaseTokenAndAedyAsExchangeTokenAndRandomPriceAndDepositAmounts(
        uint128 randomPricePerShare,
        uint128 randomDepositAmount
    ) public {
        vm.assume(randomPricePerShare != 0);
        vm.assume(randomDepositAmount != 0);
        vm.assume(randomDepositAmount <= type(uint64).max);

        deal(ADDY, ALICE, randomDepositAmount);

        vm.startPrank(admin);
        archemistAedyAddy.updatePricePerShare(randomPricePerShare);
        archemistAedyAddy.unpause();
        vm.stopPrank();

        uint256 feeAmount = (randomDepositAmount * exchangeFee) / 10000;

        uint256 depositAmount = randomDepositAmount - feeAmount;

        uint256 expectedExchangeAmount = (depositAmount * 10 ** 18) / randomPricePerShare;

        deal(AEDY, address(archemistAedyAddy), expectedExchangeAmount);

        vm.startPrank(ALICE);
        ERC20(ADDY).approve(address(archemistAedyAddy), randomDepositAmount);
        uint256 exchangeTokenAmount = archemistAedyAddy.deposit(randomDepositAmount);
        vm.stopPrank();

        assertEq(ERC20(ADDY).balanceOf(address(archemistAedyAddy)), randomDepositAmount);
        assertEq(ERC20(ADDY).balanceOf(ALICE), 0);
        assertEq(ERC20(AEDY).balanceOf(ALICE), expectedExchangeAmount);
        assertEq(ERC20(AEDY).balanceOf(address(archemistAedyAddy)), 0);
        assertEq(exchangeTokenAmount, expectedExchangeAmount);
        assertGe(exchangeTokenAmount, 0);
        assertEq(archemistAedyAddy.pricePerShare(), randomPricePerShare);
        assertEq(archemistAedyAddy.paused(), false);
    }

    /**
     * [SUCCESS] Should execute a deposit with addy as base token
     * and usdc as exchange token and random price and deposit amounts.
     */
    function testDepositWithAddyAsBaseTokenAndUsdcAsExchangeTokenAndRandomPriceAndDepositAmounts(
        uint128 randomPricePerShare,
        uint128 randomDepositAmount
    ) public {
        vm.assume(randomPricePerShare != 0);
        vm.assume(randomDepositAmount != 0);
        vm.assume(randomDepositAmount <= type(uint64).max);

        deal(ADDY, ALICE, randomDepositAmount);

        vm.startPrank(admin);
        archemistAddyUsdc.updatePricePerShare(randomPricePerShare);
        archemistAddyUsdc.unpause();
        vm.stopPrank();

        uint256 feeAmount = (randomDepositAmount * exchangeFee) / 10000;

        uint256 depositAmount = randomDepositAmount - feeAmount;

        uint256 expectedExchangeAmount = (depositAmount * 10 ** 6) / randomPricePerShare;

        deal(USDC, address(archemistAddyUsdc), expectedExchangeAmount);

        vm.startPrank(ALICE);
        ERC20(ADDY).approve(address(archemistAddyUsdc), randomDepositAmount);
        uint256 exchangeTokenAmount = archemistAddyUsdc.deposit(randomDepositAmount);
        vm.stopPrank();

        assertEq(ERC20(ADDY).balanceOf(address(archemistAddyUsdc)), randomDepositAmount);
        assertEq(ERC20(ADDY).balanceOf(ALICE), 0);
        assertEq(ERC20(USDC).balanceOf(ALICE), expectedExchangeAmount);
        assertEq(ERC20(USDC).balanceOf(address(archemistAddyUsdc)), 0);
        assertEq(exchangeTokenAmount, expectedExchangeAmount);
        assertGe(exchangeTokenAmount, 0);
        assertEq(archemistAddyUsdc.pricePerShare(), randomPricePerShare);
        assertEq(archemistAddyUsdc.paused(), false);
    }

    /**
     * [SUCCESS] Should execute a deposit with an excahnge amount equals to 0.9 (fees considered) ether when previewing deposit with usdc as
     * base token and addy as exchange with equal deposit amount and price per share.
     */
    function testDepositWithUsdcAsBaseTokenAndAedyAsExchangeTokenAndEqualDepositAmountAndPricePerShare(
    ) public {
        deal(USDC, ALICE, 1 ether);

        vm.startPrank(admin);
        archemist.updatePricePerShare(1 ether);
        archemist.unpause();
        vm.stopPrank();

        deal(AEDY, address(archemist), 0.9 ether);

        vm.startPrank(ALICE);
        ERC20(USDC).approve(address(archemist), 1 ether);
        uint256 exchangeTokenAmount = archemist.deposit(1 ether);
        vm.stopPrank();

        assertEq(ERC20(USDC).balanceOf(address(archemist)), 1 ether);
        assertEq(ERC20(USDC).balanceOf(ALICE), 0);
        assertEq(ERC20(AEDY).balanceOf(ALICE), 0.9 ether);
        assertEq(ERC20(AEDY).balanceOf(address(archemist)), 0);
        assertEq(exchangeTokenAmount, 0.9 ether);
        assertGe(exchangeTokenAmount, 0);
        assertEq(archemist.pricePerShare(), 1 ether);
        assertEq(archemist.paused(), false);
    }

    /**
     * [SUCCESS] Should execute a deposit with an excahnge amount equals to 0.9 (fees considered) ether when previewing deposit with addy as
     * base token and aedy as exchange with equal deposit amount and price per share.
     */
    function testDepositWithAddyAsBaseTokenAndAedyAsExchangeTokenAndEqualDepositAmountAndPricePerShare(
    ) public {
        deal(ADDY, ALICE, 1 ether);

        vm.startPrank(admin);
        archemistAedyAddy.updatePricePerShare(1 ether);
        archemistAedyAddy.unpause();
        vm.stopPrank();

        deal(AEDY, address(archemistAedyAddy), 0.9 ether);

        vm.startPrank(ALICE);
        ERC20(ADDY).approve(address(archemistAedyAddy), 1 ether);
        uint256 exchangeTokenAmount = archemistAedyAddy.deposit(1 ether);
        vm.stopPrank();

        assertEq(ERC20(ADDY).balanceOf(address(archemistAedyAddy)), 1 ether);
        assertEq(ERC20(ADDY).balanceOf(ALICE), 0);
        assertEq(ERC20(AEDY).balanceOf(ALICE), 0.9 ether);
        assertEq(ERC20(AEDY).balanceOf(address(archemistAedyAddy)), 0);
        assertEq(exchangeTokenAmount, 0.9 ether);
        assertGe(exchangeTokenAmount, 0);
        assertEq(archemistAedyAddy.pricePerShare(), 1 ether);
        assertEq(archemistAedyAddy.paused(), false);
    }

    /**
     * [SUCCESS] Should execute a deposit with an excahnge amount equals to 0.9 (fees considered) ether when previewing deposit with addy as
     * base token and usdc as exchange with equal deposit amount and price per share.
     */
    function testDepositWithAddyAsBaseTokenAndUsdcAsExchangeTokenAndEqualDepositAmountAndPricePerShare(
    ) public {
        deal(ADDY, ALICE, 1 ether);

        vm.startPrank(admin);
        archemistAddyUsdc.updatePricePerShare(1 ether);
        archemistAddyUsdc.unpause();
        vm.stopPrank();

        deal(USDC, address(archemistAddyUsdc), 9e5);

        vm.startPrank(ALICE);
        ERC20(ADDY).approve(address(archemistAddyUsdc), 1 ether);
        uint256 exchangeTokenAmount = archemistAddyUsdc.deposit(1 ether);
        vm.stopPrank();

        assertEq(ERC20(ADDY).balanceOf(address(archemistAddyUsdc)), 1 ether);
        assertEq(ERC20(ADDY).balanceOf(ALICE), 0);
        assertEq(ERC20(USDC).balanceOf(ALICE), 9e5);
        assertEq(ERC20(USDC).balanceOf(address(archemistAddyUsdc)), 0);
        assertEq(exchangeTokenAmount, 9e5); // 0.9 USDC
        assertGe(exchangeTokenAmount, 0);
        assertEq(archemistAddyUsdc.pricePerShare(), 1 ether);
        assertEq(archemistAddyUsdc.paused(), false);
    }
}
