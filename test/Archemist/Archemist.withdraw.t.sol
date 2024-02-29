// SPDX-License-Identifier: Apache License 2.0
pragma solidity ^0.8.24;

import { ArchemistTest } from "test/utils/ArchemistTest.sol";
import { IArchemist } from "src/interfaces/IArchemist.sol";
import { Pausable } from "@openzeppelin/contracts/utils/Pausable.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract ArchemistWithdrawTest is ArchemistTest {
    /*//////////////////////////////////////////////////////////////
                              REVERT
    //////////////////////////////////////////////////////////////*/

    /**
     * [ERROR] Should revert when withdraw with zero amount.
     */
    function testCannotWithdrawWithZeroAmount() public {
         vm.prank(admin);
        archemist.unpause();
        vm.expectRevert(abi.encodeWithSelector(IArchemist.ZeroWithdrawAmount.selector));
        archemist.withdraw(0);
    }

    /**
     * [ERROR] Should revert when withdraw with zero price per share.
     */
    function testCannotWithdrawWithZeroPricePerShare(uint128 randomWithdrawAmount) public {
         vm.prank(admin);
        archemist.unpause();
        vm.assume(randomWithdrawAmount != 0);
        vm.expectRevert(abi.encodeWithSelector(IArchemist.ZeroPricePerShare.selector));
        archemist.withdraw(randomWithdrawAmount);
    }

     /**
     * [ERROR] Should revert when withdraw is called and contract is paused.
     */
    function testCannotWithdrawWhenContractIsPaused(uint128 randomWithdrawAmount) public {
        vm.expectRevert(abi.encodeWithSelector(Pausable.EnforcedPause.selector));
        archemist.withdraw(randomWithdrawAmount);
    }

    /**
     * [ERROR] Should revert whe user has no balance at withdraw.
     */
    function testCannotWithdrawWhenUserHasNoBalance(
        uint128 randomPricePerShare,
        uint128 randomWithdrawAmount
    ) public {
        vm.assume(randomPricePerShare != 0);
        vm.assume(randomWithdrawAmount != 0);
        vm.assume(randomWithdrawAmount <= type(uint64).max);

        vm.startPrank(admin);
        archemist.updatePricePerShare(randomPricePerShare);
        archemist.unpause();
        vm.stopPrank();

        vm.expectRevert("ERC20: transfer amount exceeds balance");
        vm.prank(ALICE);
        archemist.withdraw(randomWithdrawAmount);
    }

    /**
     * [ERROR] Should revert when user has no allowance.
     */
    function testCannotWithdrawWhenUserHasNoAllowance(
        uint128 randomPricePerShare,
        uint128 randomWithdrawAmount
    ) public {
        vm.assume(randomPricePerShare != 0);
        vm.assume(randomWithdrawAmount != 0);
        vm.assume(randomWithdrawAmount <= type(uint64).max);

        vm.startPrank(admin);
        archemist.updatePricePerShare(randomPricePerShare);
        archemist.unpause();
        vm.stopPrank();

        deal(AEDY, ALICE, randomWithdrawAmount);

        vm.expectRevert("ERC20: transfer amount exceeds allowance");
        vm.prank(ALICE);
        archemist.withdraw(randomWithdrawAmount);
    }

    /**
     * [ERROR] Should revert when contract has no balance
     */
    function testCannotWithdrawWhenContractHasNoBalance(
        uint128 randomPricePerShare,
        uint128 randomWithdrawAmount
    ) public {
        vm.assume(randomPricePerShare != 0);
        vm.assume(randomWithdrawAmount != 0);
        vm.assume(randomWithdrawAmount <= type(uint64).max);

        vm.startPrank(admin);
        archemist.updatePricePerShare(randomPricePerShare);
        archemist.unpause();
        vm.stopPrank();

        deal(AEDY, address(archemist), randomWithdrawAmount);

        vm.startPrank(ALICE);
        ERC20(AEDY).approve(address(archemist), randomWithdrawAmount);

        vm.expectRevert("ERC20: transfer amount exceeds balance");
        
        archemist.withdraw(randomWithdrawAmount);

        vm.stopPrank();
    }
    

    /*//////////////////////////////////////////////////////////////
                              SUCCESS
    //////////////////////////////////////////////////////////////*/

    /**
     * [SUCCESS] Should transfer the correct amount of base token when withdraw with usdc as base token
    * and aedy as exchange token and random price and withdraw amounts.
     */
    function testWithdrawWithUsdcAsBaseTokenAndAedyAsExchangeTokenAndRandomPriceAndWithdrawAmounts(
        uint256 randomPricePerShare,
        uint256 randomWithdrawAmount
    ) public {
        vm.assume(randomPricePerShare != 0);
        vm.assume(randomPricePerShare <= type(uint128).max);
        vm.assume(randomWithdrawAmount != 0);
        vm.assume(randomWithdrawAmount <= type(uint64).max);

        vm.startPrank(admin);
        archemist.updatePricePerShare(randomPricePerShare);
        archemist.unpause();
        vm.stopPrank();

        uint256 baseTokenAmountWithoutChargingFees =
            (randomWithdrawAmount * randomPricePerShare) / 10 ** 18;

        uint256 feeAmount = (baseTokenAmountWithoutChargingFees * exchangeFee) / 10000;

        uint256 expectedWithdrawAmount = baseTokenAmountWithoutChargingFees - feeAmount;

        deal(USDC, address(archemist), baseTokenAmountWithoutChargingFees);
        deal(AEDY, ALICE, randomWithdrawAmount);

        vm.startPrank(ALICE);
        ERC20(AEDY).approve(address(archemist), randomWithdrawAmount);
        uint256 baseTokenAmount = archemist.withdraw(randomWithdrawAmount);
        vm.stopPrank();

        assertEq(baseTokenAmount, ERC20(USDC).balanceOf(ALICE));
        assertEq(feeAmount, ERC20(USDC).balanceOf(address(archemist)));
        assertEq(randomWithdrawAmount, ERC20(AEDY).balanceOf(address(archemist)));
        assertEq(0, ERC20(AEDY).balanceOf(ALICE));
        assertEq(baseTokenAmount, expectedWithdrawAmount);
        assertGe(baseTokenAmount, 0);
        assertEq(archemist.pricePerShare(), randomPricePerShare);
        assertEq(archemist.paused(), false);
    }

    /**
     * [SUCCESS] Should transfer the correct amount of base token when withdraw with addy as base token
    * and aedy as exchange token and random price and withdraw amounts.
     */
    function testWithdrawWithAddyAsBaseTokenAndAedyAsExchangeTokenAndRandomPriceAndWithdrawAmounts(
        uint256 randomPricePerShare,
        uint256 randomWithdrawAmount
    ) public {
        vm.assume(randomPricePerShare != 0);
        vm.assume(randomPricePerShare <= type(uint128).max);
        vm.assume(randomWithdrawAmount != 0);
        vm.assume(randomWithdrawAmount <= type(uint64).max);

        vm.startPrank(admin);
        archemistAedyAddy.updatePricePerShare(randomPricePerShare);
        archemistAedyAddy.unpause();
        vm.stopPrank();

        uint256 baseTokenAmountWithoutChargingFees =
            (randomWithdrawAmount * randomPricePerShare) / 10 ** 18;

        uint256 feeAmount = (baseTokenAmountWithoutChargingFees * exchangeFee) / 10000;

        uint256 expectedWithdrawAmount = baseTokenAmountWithoutChargingFees - feeAmount;

        deal(ADDY, address(archemistAedyAddy), baseTokenAmountWithoutChargingFees);
        deal(AEDY, ALICE, randomWithdrawAmount);

        vm.startPrank(ALICE);
        ERC20(AEDY).approve(address(archemistAedyAddy), randomWithdrawAmount);
        uint256 baseTokenAmount = archemistAedyAddy.withdraw(randomWithdrawAmount);
        vm.stopPrank();

        assertEq(baseTokenAmount, ERC20(ADDY).balanceOf(ALICE));
        assertEq(feeAmount, ERC20(ADDY).balanceOf(address(archemistAedyAddy)));
        assertEq(randomWithdrawAmount, ERC20(AEDY).balanceOf(address(archemistAedyAddy)));
        assertEq(0, ERC20(AEDY).balanceOf(ALICE));
        assertEq(baseTokenAmount, expectedWithdrawAmount);
        assertGe(baseTokenAmount, 0);
        assertEq(archemistAedyAddy.pricePerShare(), randomPricePerShare);
        assertEq(archemistAedyAddy.paused(), false);
    }

    /**
     * [SUCCESS] Should transfer the correct amount of base token when withdraw with addy as base token
    * and usdc as exchange token and random price and withdraw amounts.
     */
    function testWithdrawWithAddyAsBaseTokenAndUsdcAsExchangeTokenAndRandomPriceAndWithdrawAmounts(
        uint256 randomPricePerShare,
        uint256 randomWithdrawAmount
    ) public {
        vm.assume(randomPricePerShare != 0);
        vm.assume(randomPricePerShare <= type(uint128).max);
        vm.assume(randomWithdrawAmount != 0);
        vm.assume(randomWithdrawAmount <= type(uint64).max);

        vm.startPrank(admin);
        archemistAddyUsdc.updatePricePerShare(randomPricePerShare);
        archemistAddyUsdc.unpause();
        vm.stopPrank();

        uint256 baseTokenAmountWithoutChargingFees =
            (randomWithdrawAmount * randomPricePerShare) / 10 ** 6;

        uint256 feeAmount = (baseTokenAmountWithoutChargingFees * exchangeFee) / 10000;

        uint256 expectedWithdrawAmount = baseTokenAmountWithoutChargingFees - feeAmount;

        deal(ADDY, address(archemistAddyUsdc), baseTokenAmountWithoutChargingFees);
        deal(USDC, ALICE, randomWithdrawAmount);

        vm.startPrank(ALICE);
        ERC20(USDC).approve(address(archemistAddyUsdc), randomWithdrawAmount);
        uint256 baseTokenAmount = archemistAddyUsdc.withdraw(randomWithdrawAmount);
        vm.stopPrank();

        assertEq(baseTokenAmount, ERC20(ADDY).balanceOf(ALICE));
        assertEq(feeAmount, ERC20(ADDY).balanceOf(address(archemistAddyUsdc)));
        assertEq(randomWithdrawAmount, ERC20(USDC).balanceOf(address(archemistAddyUsdc)));
        assertEq(0, ERC20(USDC).balanceOf(ALICE));
        assertEq(baseTokenAmount, expectedWithdrawAmount);
        assertGe(baseTokenAmount, 0);
        assertEq(archemistAddyUsdc.pricePerShare(), randomPricePerShare);
        assertEq(archemistAddyUsdc.paused(), false);
    }

    /**
     * [SUCCESS] Should transfer the correct amount of base token when withdraw with usdc as base token
    * and aedy as exchange token and fixed amounts.
     */
    function testWithdrawWithUsdcAsBaseTokenAndAedyAsExchangeTokenAndFixedAmounts() public {
        vm.startPrank(admin);
        archemist.updatePricePerShare(1e6);
        archemist.unpause();
        vm.stopPrank();

        deal(USDC, address(archemist), 1e6);
        deal(AEDY, ALICE, 1 ether);

        vm.startPrank(ALICE);
        ERC20(AEDY).approve(address(archemist), 1 ether);
        uint256 baseTokenAmount = archemist.withdraw(1 ether);
        vm.stopPrank();

        assertEq(baseTokenAmount, ERC20(USDC).balanceOf(ALICE));
        assertEq(0, ERC20(AEDY).balanceOf(ALICE));
        assertEq(1e5, ERC20(USDC).balanceOf(address(archemist)));
        assertEq(1 ether, ERC20(AEDY).balanceOf(address(archemist)));
        assertEq(baseTokenAmount, 9e5);
        assertEq(archemist.pricePerShare(), 1e6);
        assertEq(archemist.paused(), false);
    }

    /**
     * [SUCCESS] Should transfer the correct amount of base token when withdraw with addy as base token
    * and aedy as exchange token and fixed amounts.
     */
    function testWithdrawWithAddyAsBaseTokenAndAedyAsExchangeTokenAndFixedAmounts() public {
        vm.startPrank(admin);
        archemistAedyAddy.updatePricePerShare(1 ether);
        archemistAedyAddy.unpause();
        vm.stopPrank();

        deal(ADDY, address(archemistAedyAddy), 1 ether);
        deal(AEDY, ALICE, 1 ether);

        vm.startPrank(ALICE);
        ERC20(AEDY).approve(address(archemistAedyAddy), 1 ether);
        uint256 baseTokenAmount = archemistAedyAddy.withdraw(1 ether);
        vm.stopPrank();

        assertEq(baseTokenAmount, ERC20(ADDY).balanceOf(ALICE));
        assertEq(0, ERC20(AEDY).balanceOf(ALICE));
        assertEq(0.1 ether, ERC20(ADDY).balanceOf(address(archemistAedyAddy)));
        assertEq(1 ether, ERC20(AEDY).balanceOf(address(archemistAedyAddy)));
        assertEq(baseTokenAmount, 0.9 ether);
        assertEq(archemistAedyAddy.pricePerShare(), 1 ether);
        assertEq(archemistAedyAddy.paused(), false);
    }

    /**
     * [SUCCESS] Should transfer the correct amount of base token when withdraw with addy as base token
    * and usdc as exchange token and fixed amounts.
     */
    function testWithdrawWithAddyAsBaseTokenAndUsdcAsExchangeTokenAndFixedAmounts() public {
        vm.startPrank(admin);
        archemistAddyUsdc.updatePricePerShare(1 ether);
        archemistAddyUsdc.unpause();
        vm.stopPrank();

        deal(ADDY, address(archemistAddyUsdc), 1 ether);
        deal(USDC, ALICE, 1e6);

        vm.startPrank(ALICE);
        ERC20(USDC).approve(address(archemistAddyUsdc), 1e6);
        uint256 baseTokenAmount = archemistAddyUsdc.withdraw(1e6);
        vm.stopPrank();

        assertEq(baseTokenAmount, ERC20(ADDY).balanceOf(ALICE));
        assertEq(0, ERC20(USDC).balanceOf(ALICE));
        assertEq(0.1 ether, ERC20(ADDY).balanceOf(address(archemistAddyUsdc)));
        assertEq(1e6, ERC20(USDC).balanceOf(address(archemistAddyUsdc)));
        assertEq(baseTokenAmount, 0.9 ether);
        assertEq(archemistAddyUsdc.pricePerShare(), 1 ether);
        assertEq(archemistAddyUsdc.paused(), false);
    }
}
