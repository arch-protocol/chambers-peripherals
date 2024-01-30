// Copyright 2023 Smash Works Inc.
// SPDX-License-Identifier: Apache License 2.0
pragma solidity ^0.8.17.0;

import { console } from "forge-std/console.sol";
import { ChamberTestUtils } from "test/utils/ChamberTestUtils.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { ChamberGod } from "chambers/ChamberGod.sol";
import { Chamber } from "chambers/Chamber.sol";
import { IssuerWizard } from "chambers/IssuerWizard.sol";
import { IVault } from "src/interfaces/IVault.sol";
import { IChamber } from "chambers/interfaces/IChamber.sol";
import { IIssuerWizard } from "chambers/interfaces/IIssuerWizard.sol";
import { PreciseUnitMath } from "chambers/lib/PreciseUnitMath.sol";
import { TradeIssuerV2 } from "src/TradeIssuerV2.sol";
import { ITradeIssuerV2 } from "src/interfaces/ITradeIssuerV2.sol";
import { stdError } from "forge-std/StdError.sol";

contract TradeIssuerV2IntegrationRedeemChamberToNativeTokenTest is ChamberTestUtils {
    using PreciseUnitMath for uint256;
    using PreciseUnitMath for uint64;

    /*//////////////////////////////////////////////////////////////
                              VARIABLES
    //////////////////////////////////////////////////////////////*/

    TradeIssuerV2 public tradeIssuer;
    ChamberGod public chamberGod = ChamberGod(0x0C9Aa1e4B4E39DA01b7459607995368E4C38cFEF);
    Chamber public addyToken = Chamber(0xE15A66b7B8e385CAa6F69FD0d55984B96D7263CF);
    IssuerWizard public issuerWizard = IssuerWizard(0x60F56236CD3C1Ac146BD94F2006a1335BaA4c449);
    bytes4 public yearnWithdraw = bytes4(keccak256("withdraw(uint256)"));
    address payable public alice = payable(address(0x123456));
    address payable public dexAgg = payable(address(0xDef1C0ded9bec7F1a1670819833240f027b25EfF));
    mapping(string => address) public tokens;
    uint256[] public componentQuantities = new uint256[](3);

    /*//////////////////////////////////////////////////////////////
                              SET UP
    //////////////////////////////////////////////////////////////*/

    function setUp() public {
        tokens["weth"] = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
        tokens["dai"] = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
        tokens["usdc"] = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
        tokens["usdt"] = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
        tokens["ydai"] = 0xdA816459F1AB5631232FE5e97a05BBBb94970c95;
        tokens["yusdc"] = 0xa354F35829Ae975e850e23e9615b11Da1B3dC4DE;
        tokens["yusdt"] = 0x3B27F92C0e212C671EA351827EDF93DB27cc0c65;

        tradeIssuer = new TradeIssuerV2(tokens["weth"]);
        tradeIssuer.addTarget(dexAgg);
        tradeIssuer.addTarget(tokens["yusdc"]);
        tradeIssuer.addTarget(tokens["ydai"]);
        tradeIssuer.addTarget(tokens["yusdt"]);

        vm.label(address(issuerWizard), "IssuerWizard");
        vm.label(address(chamberGod), "ChamberGod");
        vm.label(alice, "Alice");
        vm.label(dexAgg, "ZeroEx");
        vm.label(tokens["weth"], "WETH");
        vm.label(tokens["usdc"], "USDC");
        vm.label(tokens["dai"], "DAI");
        vm.label(tokens["usdt"], "USDT");
        vm.label(tokens["yusdc"], "yUSDC");
        vm.label(tokens["yudst"], "yUSDT");
        vm.label(tokens["ydai"], "yDAI");
    }

    /*//////////////////////////////////////////////////////////////
                              REVERT
    //////////////////////////////////////////////////////////////*/

    /**
     * [REVERT] Cannot redeem zero chamber amount.
     */
    function testCannotRedeemZeroChamberAmount() public {
        ITradeIssuerV2.ContractCallInstruction[] memory instructions =
            new ITradeIssuerV2.ContractCallInstruction[](1);

        vm.prank(alice);
        vm.expectRevert(ITradeIssuerV2.ZeroChamberAmount.selector);
        uint256 totalBaseTokenReturned =
            tradeIssuer.redeemChamberToNativeToken(instructions, addyToken, issuerWizard, 1e6, 0);
        assertEq(totalBaseTokenReturned, 0);
    }

    /**
     * [REVERT] Cannot redeem without chamber token approval.
     */
    function testCannotRedeemWithoutChamberTokenApproval() public {
        ITradeIssuerV2.ContractCallInstruction[] memory instructions =
            new ITradeIssuerV2.ContractCallInstruction[](1);

        deal(address(addyToken), alice, 1e6);

        vm.prank(alice);
        vm.expectRevert(stdError.arithmeticError);
        uint256 totalBaseTokenReturned =
            tradeIssuer.redeemChamberToNativeToken(instructions, addyToken, issuerWizard, 1e6, 1e18);
        assertEq(totalBaseTokenReturned, 0);
    }

    /**
     * [REVERT] Cannot redeem without chamber token balance.
     */
    function testCannotRedeemWithoutChamberTokenBalance() public {
        ITradeIssuerV2.ContractCallInstruction[] memory instructions =
            new ITradeIssuerV2.ContractCallInstruction[](1);

        vm.prank(alice);
        addyToken.approve(address(tradeIssuer), 1e18);

        vm.prank(alice);
        vm.expectRevert(stdError.arithmeticError);
        uint256 totalBaseTokenReturned = tradeIssuer.redeemChamberToNativeToken(
            instructions, addyToken, issuerWizard, 1e18, 1e18
        );
        assertEq(totalBaseTokenReturned, 0);
    }

    /**
     * [REVERT] Cannot redeem with underbought asset in an instruction.
     */
    function testCannotRedeemWithUnderboughtAsset() public {
        ITradeIssuerV2.ContractCallInstruction[] memory instructions =
            new ITradeIssuerV2.ContractCallInstruction[](1);
        (, uint256[] memory requiredQuantities) =
            issuerWizard.getConstituentsQuantitiesForIssuance(addyToken, 500e18);

        componentQuantities[0] = (
            PreciseUnitMath.preciseMulCeil(1e18, requiredQuantities[0], 18).preciseMulCeil(
                IVault(tokens["ydai"]).pricePerShare(), 18
            )
        );

        uint256 badQuantities = componentQuantities[0] * 10; //requiring 10x the amount of dai that will be bought

        instructions[0] = ITradeIssuerV2.ContractCallInstruction(
            payable(tokens["ydai"]),
            tokens["ydai"],
            IERC20(tokens["ydai"]),
            requiredQuantities[0],
            IERC20(tokens["dai"]),
            badQuantities,
            abi.encodeWithSelector(yearnWithdraw, requiredQuantities[0])
        );

        uint256 minAmountOutputToken = ((badQuantities) * 999 / 1000);

        deal(address(addyToken), alice, 500e18);
        deal(tokens["ydai"], address(addyToken), requiredQuantities[0]);
        deal(tokens["yusdc"], address(addyToken), requiredQuantities[1]);
        deal(tokens["yusdt"], address(addyToken), requiredQuantities[2]);

        vm.prank(alice);
        addyToken.approve(address(tradeIssuer), 500e18);
        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(
                ITradeIssuerV2.UnderboughtAsset.selector, tokens["dai"], badQuantities
            )
        );
        uint256 totalBaseTokenReturned = tradeIssuer.redeemChamberToNativeToken(
            instructions, addyToken, issuerWizard, minAmountOutputToken, 500e18
        );
        assertEq(totalBaseTokenReturned, 0);
    }

    /**
     * [REVERT] Cannot redeem with bad call data in an instruction.
     */
    function testCannotRedeemWithBadQuoteData() public {
        ITradeIssuerV2.ContractCallInstruction[] memory instructions =
            new ITradeIssuerV2.ContractCallInstruction[](1);
        (, uint256[] memory requiredQuantities) =
            issuerWizard.getConstituentsQuantitiesForIssuance(addyToken, 500e18);

        componentQuantities[0] = (
            PreciseUnitMath.preciseMulCeil(1e18, requiredQuantities[0], 18).preciseMulCeil(
                IVault(tokens["ydai"]).pricePerShare(), 18
            )
        );

        bytes memory badQuotes = bytes("BADQUOTE");

        instructions[0] = ITradeIssuerV2.ContractCallInstruction(
            payable(tokens["ydai"]),
            tokens["ydai"],
            IERC20(tokens["ydai"]),
            requiredQuantities[0],
            IERC20(tokens["dai"]),
            componentQuantities[0],
            badQuotes
        );

        uint256 minAmountOutputToken = ((componentQuantities[0]) * 101 / 100);

        deal(address(addyToken), alice, 500e18);
        deal(tokens["ydai"], address(addyToken), requiredQuantities[0]);
        deal(tokens["yusdc"], address(addyToken), requiredQuantities[1]);
        deal(tokens["yusdt"], address(addyToken), requiredQuantities[2]);

        vm.prank(alice);
        addyToken.approve(address(tradeIssuer), 500e18);
        vm.prank(alice);

        vm.expectRevert("Address: low-level call failed");
        uint256 totalBaseTokenReturned = tradeIssuer.redeemChamberToNativeToken(
            instructions, addyToken, issuerWizard, minAmountOutputToken, 500e18
        );
        assertEq(totalBaseTokenReturned, 0);
    }

    /**
     * [REVERT] Cannot redeem with invalid target in an instruction.
     */
    function testCannotRedeemWithInvalidTarget() public {
        address payable invalidTarget = payable(address(0x123));
        ITradeIssuerV2.ContractCallInstruction[] memory instructions =
            new ITradeIssuerV2.ContractCallInstruction[](1);
        (, uint256[] memory requiredQuantities) =
            issuerWizard.getConstituentsQuantitiesForIssuance(addyToken, 500e18);

        componentQuantities[0] = (
            PreciseUnitMath.preciseMulCeil(1e18, requiredQuantities[0], 18).preciseMulCeil(
                IVault(tokens["ydai"]).pricePerShare(), 18
            )
        );

        instructions[0] = ITradeIssuerV2.ContractCallInstruction(
            invalidTarget,
            invalidTarget,
            IERC20(tokens["ydai"]),
            requiredQuantities[0],
            IERC20(tokens["dai"]),
            componentQuantities[0],
            abi.encodeWithSelector(yearnWithdraw, requiredQuantities[0])
        );

        uint256 minAmountOutputToken = ((componentQuantities[0]) * 999 / 1000);

        deal(address(addyToken), alice, 500e18);
        deal(tokens["ydai"], address(addyToken), requiredQuantities[0]);
        deal(tokens["yusdc"], address(addyToken), requiredQuantities[1]);
        deal(tokens["yusdt"], address(addyToken), requiredQuantities[2]);

        vm.prank(alice);
        addyToken.approve(address(tradeIssuer), 500e18);
        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(ITradeIssuerV2.InvalidTarget.selector, invalidTarget)
        );
        uint256 totalBaseTokenReturned = tradeIssuer.redeemChamberToNativeToken(
            instructions, addyToken, issuerWizard, minAmountOutputToken, 500e18
        );
        assertEq(totalBaseTokenReturned, 0);
    }

    /**
     * [REVERT] Cannot redeem with underbought wrapped native token after executing all instructions.
     */
    function testCannotRedeemAddyWithUnderBoughtBaseToken() public {
        ITradeIssuerV2.ContractCallInstruction[] memory instructions =
            new ITradeIssuerV2.ContractCallInstruction[](6);
        (, uint256[] memory requiredQuantities) =
            issuerWizard.getConstituentsQuantitiesForIssuance(addyToken, 500e18);

        componentQuantities[0] = (
            PreciseUnitMath.preciseMulCeil(1e18, requiredQuantities[0], 18).preciseMulCeil(
                IVault(tokens["ydai"]).pricePerShare(), 18
            )
        );

        componentQuantities[1] = (
            PreciseUnitMath.preciseMulCeil(1e18, requiredQuantities[1], 18).preciseMulCeil(
                IVault(tokens["yusdc"]).pricePerShare(), 6
            )
        );

        componentQuantities[2] = (
            PreciseUnitMath.preciseMulCeil(1e18, requiredQuantities[2], 18).preciseMulCeil(
                IVault(tokens["yusdt"]).pricePerShare(), 6
            )
        );

        (bytes memory quotes0, uint256 buyAmount0) =
            getQuoteDataForRedeem(componentQuantities[0], tokens["dai"], tokens["weth"]);
        (bytes memory quotes1, uint256 buyAmount1) =
            getQuoteDataForRedeem(componentQuantities[1], tokens["usdc"], tokens["weth"]);
        (bytes memory quotes2, uint256 buyAmount2) =
            getQuoteDataForRedeem(componentQuantities[2], tokens["usdt"], tokens["weth"]);

        instructions[0] = ITradeIssuerV2.ContractCallInstruction(
            payable(tokens["ydai"]),
            tokens["ydai"],
            IERC20(tokens["ydai"]),
            requiredQuantities[0],
            IERC20(tokens["dai"]),
            componentQuantities[0],
            abi.encodeWithSelector(yearnWithdraw, requiredQuantities[0])
        );

        instructions[1] = ITradeIssuerV2.ContractCallInstruction(
            payable(tokens["yusdc"]),
            tokens["yusdc"],
            IERC20(tokens["yusdc"]),
            requiredQuantities[1],
            IERC20(tokens["usdc"]),
            componentQuantities[1],
            abi.encodeWithSelector(yearnWithdraw, requiredQuantities[1])
        );

        instructions[2] = ITradeIssuerV2.ContractCallInstruction(
            payable(tokens["yusdt"]),
            tokens["yusdt"],
            IERC20(tokens["yusdt"]),
            requiredQuantities[2],
            IERC20(tokens["usdt"]),
            componentQuantities[2],
            abi.encodeWithSelector(yearnWithdraw, requiredQuantities[2])
        );

        instructions[3] = ITradeIssuerV2.ContractCallInstruction(
            dexAgg,
            dexAgg,
            IERC20(tokens["dai"]),
            componentQuantities[0],
            IERC20(tokens["weth"]),
            buyAmount0,
            quotes0
        );

        instructions[4] = ITradeIssuerV2.ContractCallInstruction(
            dexAgg,
            dexAgg,
            IERC20(tokens["usdc"]),
            componentQuantities[1],
            IERC20(tokens["weth"]),
            buyAmount1,
            quotes1
        );

        instructions[5] = ITradeIssuerV2.ContractCallInstruction(
            dexAgg,
            dexAgg,
            IERC20(tokens["usdt"]),
            componentQuantities[2],
            IERC20(tokens["weth"]),
            buyAmount2,
            quotes2
        );

        uint256 minAmountOutputToken = ((buyAmount0 + buyAmount1 + buyAmount2) * 999 / 1000);

        uint256 bigOutputToken = minAmountOutputToken * 1000;

        deal(address(addyToken), alice, 500e18);
        deal(tokens["ydai"], address(addyToken), requiredQuantities[0]);
        deal(tokens["yusdc"], address(addyToken), requiredQuantities[1]);
        deal(tokens["yusdt"], address(addyToken), requiredQuantities[2]);

        vm.prank(alice);
        IERC20(address(addyToken)).approve(address(tradeIssuer), 500e18);

        vm.prank(alice);
        vm.expectRevert(ITradeIssuerV2.RedeemedForLessTokens.selector);
        uint256 totalBaseTokenReturned = tradeIssuer.redeemChamberToNativeToken(
            instructions, addyToken, issuerWizard, bigOutputToken, 500e18
        );

        assertEq(totalBaseTokenReturned, 0);
    }

    /**
     * [REVERT] Cannot redeem instructions array with wrong order
     */
    function testCannotRedeemWithWrongOrderAtInstructionsArray() public {
        ITradeIssuerV2.ContractCallInstruction[] memory instructions =
            new ITradeIssuerV2.ContractCallInstruction[](6);
        (, uint256[] memory requiredQuantities) =
            issuerWizard.getConstituentsQuantitiesForIssuance(addyToken, 500e18);

        componentQuantities[0] = (
            PreciseUnitMath.preciseMulCeil(1e18, requiredQuantities[0], 18).preciseMulCeil(
                IVault(tokens["ydai"]).pricePerShare(), 18
            )
        );

        componentQuantities[1] = (
            PreciseUnitMath.preciseMulCeil(1e18, requiredQuantities[1], 18).preciseMulCeil(
                IVault(tokens["yusdc"]).pricePerShare(), 6
            )
        );

        componentQuantities[2] = (
            PreciseUnitMath.preciseMulCeil(1e18, requiredQuantities[2], 18).preciseMulCeil(
                IVault(tokens["yusdt"]).pricePerShare(), 6
            )
        );

        (bytes memory quotes0, uint256 buyAmount0) =
            getQuoteDataForRedeem(componentQuantities[0], tokens["dai"], tokens["weth"]);

        /**
         * Will try to swap before making a withdraw from the yearn vault. Wont have the underlying
         * Asset for the swap.
         */
        instructions[0] = ITradeIssuerV2.ContractCallInstruction(
            dexAgg,
            dexAgg,
            IERC20(tokens["dai"]),
            componentQuantities[0],
            IERC20(tokens["weth"]),
            buyAmount0 * 999 / 1000,
            quotes0
        );

        instructions[1] = ITradeIssuerV2.ContractCallInstruction(
            payable(tokens["ydai"]),
            tokens["ydai"],
            IERC20(tokens["ydai"]),
            requiredQuantities[0],
            IERC20(tokens["dai"]),
            componentQuantities[0],
            abi.encodeWithSelector(yearnWithdraw, requiredQuantities[0])
        );

        uint256 minAmountOutputToken = ((buyAmount0) * 999 / 1000);

        deal(address(addyToken), alice, 500e18);
        deal(tokens["ydai"], address(addyToken), requiredQuantities[0]);
        deal(tokens["yusdc"], address(addyToken), requiredQuantities[1]);
        deal(tokens["yusdt"], address(addyToken), requiredQuantities[2]);

        vm.prank(alice);
        IERC20(address(addyToken)).approve(address(tradeIssuer), 500e18);

        vm.prank(alice);
        vm.expectRevert();
        uint256 totalBaseTokenReturned = tradeIssuer.redeemChamberToNativeToken(
            instructions, addyToken, issuerWizard, minAmountOutputToken, 500e18
        );

        assertEq(totalBaseTokenReturned, 0);
    }

    /*//////////////////////////////////////////////////////////////
                              SUCCESS
    //////////////////////////////////////////////////////////////*/

    /**
     * [SUCCESS] Redeem a chamber token to native token
     */
    function testSuccessRedeemAddyToNativeToken() public {
        ITradeIssuerV2.ContractCallInstruction[] memory instructions =
            new ITradeIssuerV2.ContractCallInstruction[](6);
        (, uint256[] memory requiredQuantities) =
            issuerWizard.getConstituentsQuantitiesForIssuance(addyToken, 500e18);

        componentQuantities[0] = (
            PreciseUnitMath.preciseMulCeil(1e18, requiredQuantities[0], 18).preciseMulCeil(
                IVault(tokens["ydai"]).pricePerShare(), 18
            )
        );

        componentQuantities[1] = (
            PreciseUnitMath.preciseMulCeil(1e18, requiredQuantities[1], 18).preciseMulCeil(
                IVault(tokens["yusdc"]).pricePerShare(), 6
            )
        );

        componentQuantities[2] = (
            PreciseUnitMath.preciseMulCeil(1e18, requiredQuantities[2], 18).preciseMulCeil(
                IVault(tokens["yusdt"]).pricePerShare(), 6
            )
        );

        (bytes memory quotes0, uint256 buyAmount0) =
            getQuoteDataForRedeem(componentQuantities[0], tokens["dai"], tokens["weth"]);
        (bytes memory quotes1, uint256 buyAmount1) =
            getQuoteDataForRedeem(componentQuantities[1], tokens["usdc"], tokens["weth"]);
        (bytes memory quotes2, uint256 buyAmount2) =
            getQuoteDataForRedeem(componentQuantities[2], tokens["usdt"], tokens["weth"]);

        instructions[0] = ITradeIssuerV2.ContractCallInstruction(
            payable(tokens["ydai"]),
            tokens["ydai"],
            IERC20(tokens["ydai"]),
            requiredQuantities[0],
            IERC20(tokens["dai"]),
            componentQuantities[0],
            abi.encodeWithSelector(yearnWithdraw, requiredQuantities[0])
        );

        instructions[1] = ITradeIssuerV2.ContractCallInstruction(
            payable(tokens["yusdc"]),
            tokens["yusdc"],
            IERC20(tokens["yusdc"]),
            requiredQuantities[1],
            IERC20(tokens["usdc"]),
            componentQuantities[1],
            abi.encodeWithSelector(yearnWithdraw, requiredQuantities[1])
        );

        instructions[2] = ITradeIssuerV2.ContractCallInstruction(
            payable(tokens["yusdt"]),
            tokens["yusdt"],
            IERC20(tokens["yusdt"]),
            requiredQuantities[2],
            IERC20(tokens["usdt"]),
            componentQuantities[2],
            abi.encodeWithSelector(yearnWithdraw, requiredQuantities[2])
        );

        instructions[3] = ITradeIssuerV2.ContractCallInstruction(
            dexAgg,
            dexAgg,
            IERC20(tokens["dai"]),
            componentQuantities[0],
            IERC20(tokens["weth"]),
            buyAmount0,
            quotes0
        );

        instructions[4] = ITradeIssuerV2.ContractCallInstruction(
            dexAgg,
            dexAgg,
            IERC20(tokens["usdc"]),
            componentQuantities[1],
            IERC20(tokens["weth"]),
            buyAmount1,
            quotes1
        );

        instructions[5] = ITradeIssuerV2.ContractCallInstruction(
            dexAgg,
            dexAgg,
            IERC20(tokens["usdt"]),
            componentQuantities[2],
            IERC20(tokens["weth"]),
            buyAmount2,
            quotes2
        );

        uint256 minAmountOutputToken = ((buyAmount0 + buyAmount1 + buyAmount2) * 999 / 1000);

        deal(address(addyToken), alice, 500e18);
        deal(tokens["ydai"], address(addyToken), requiredQuantities[0]);
        deal(tokens["yusdc"], address(addyToken), requiredQuantities[1]);
        deal(tokens["yusdt"], address(addyToken), requiredQuantities[2]);

        vm.prank(alice);
        IERC20(address(addyToken)).approve(address(tradeIssuer), 500e18);

        vm.prank(alice);
        uint256 totalBaseTokenReturned = tradeIssuer.redeemChamberToNativeToken(
            instructions, addyToken, issuerWizard, minAmountOutputToken, 500e18
        );

        assertEq(addyToken.balanceOf(alice), 0);
        assertEq(addyToken.balanceOf(address(tradeIssuer)), 0);
        assertEq((address(tradeIssuer)).balance, 0);
        assertEq(alice.balance, totalBaseTokenReturned);
        assertGe(alice.balance, minAmountOutputToken);
        console.log("Redeemed Tokens:");
        console.log(totalBaseTokenReturned);
        console.log("Remaining DAI:");
        console.log(IERC20(tokens["dai"]).balanceOf(address(tradeIssuer)));
        console.log("Remaining yDAI:");
        console.log(IERC20(tokens["ydai"]).balanceOf(address(tradeIssuer)));
        console.log("Remaining USDT:");
        console.log(IERC20(tokens["usdt"]).balanceOf(address(tradeIssuer)));
        console.log("Remaining yUSDT:");
        console.log(IERC20(tokens["yusdt"]).balanceOf(address(tradeIssuer)));
        console.log("Remaining USDC:");
        console.log(IERC20(tokens["usdc"]).balanceOf(address(tradeIssuer)));
        console.log("Remaining yUSDC:");
        console.log(IERC20(tokens["yusdc"]).balanceOf(address(tradeIssuer)));
    }

    /**
     * [SUCCESS] Redeem a chamber token to native token but in a different valid order of the instructions array
     * as the above test.
     */
    function testSuccessRedeemAddyToNativeTokenInDifferentOrder() public {
        ITradeIssuerV2.ContractCallInstruction[] memory instructions =
            new ITradeIssuerV2.ContractCallInstruction[](6);
        (, uint256[] memory requiredQuantities) =
            issuerWizard.getConstituentsQuantitiesForIssuance(addyToken, 500e18);

        componentQuantities[0] = (
            PreciseUnitMath.preciseMulCeil(1e18, requiredQuantities[0], 18).preciseMulCeil(
                IVault(tokens["ydai"]).pricePerShare(), 18
            )
        );

        componentQuantities[1] = (
            PreciseUnitMath.preciseMulCeil(1e18, requiredQuantities[1], 18).preciseMulCeil(
                IVault(tokens["yusdc"]).pricePerShare(), 6
            )
        );

        componentQuantities[2] = (
            PreciseUnitMath.preciseMulCeil(1e18, requiredQuantities[2], 18).preciseMulCeil(
                IVault(tokens["yusdt"]).pricePerShare(), 6
            )
        );

        (bytes memory quotes0, uint256 buyAmount0) =
            getQuoteDataForRedeem(componentQuantities[0], tokens["dai"], tokens["weth"]);
        (bytes memory quotes1, uint256 buyAmount1) =
            getQuoteDataForRedeem(componentQuantities[1], tokens["usdc"], tokens["weth"]);
        (bytes memory quotes2, uint256 buyAmount2) =
            getQuoteDataForRedeem(componentQuantities[2], tokens["usdt"], tokens["weth"]);

        instructions[0] = ITradeIssuerV2.ContractCallInstruction(
            payable(tokens["ydai"]),
            tokens["ydai"],
            IERC20(tokens["ydai"]),
            requiredQuantities[0],
            IERC20(tokens["dai"]),
            componentQuantities[0],
            abi.encodeWithSelector(yearnWithdraw, requiredQuantities[0])
        );

        instructions[2] = ITradeIssuerV2.ContractCallInstruction(
            payable(tokens["yusdc"]),
            tokens["yusdc"],
            IERC20(tokens["yusdc"]),
            requiredQuantities[1],
            IERC20(tokens["usdc"]),
            componentQuantities[1],
            abi.encodeWithSelector(yearnWithdraw, requiredQuantities[1])
        );

        instructions[4] = ITradeIssuerV2.ContractCallInstruction(
            payable(tokens["yusdt"]),
            tokens["yusdt"],
            IERC20(tokens["yusdt"]),
            requiredQuantities[2],
            IERC20(tokens["usdt"]),
            componentQuantities[2],
            abi.encodeWithSelector(yearnWithdraw, requiredQuantities[2])
        );

        instructions[1] = ITradeIssuerV2.ContractCallInstruction(
            dexAgg,
            dexAgg,
            IERC20(tokens["dai"]),
            componentQuantities[0],
            IERC20(tokens["weth"]),
            buyAmount0 * 999 / 1000,
            quotes0
        );

        instructions[3] = ITradeIssuerV2.ContractCallInstruction(
            dexAgg,
            dexAgg,
            IERC20(tokens["usdc"]),
            componentQuantities[1],
            IERC20(tokens["weth"]),
            buyAmount1 * 999 / 1000,
            quotes1
        );

        instructions[5] = ITradeIssuerV2.ContractCallInstruction(
            dexAgg,
            dexAgg,
            IERC20(tokens["usdt"]),
            componentQuantities[2],
            IERC20(tokens["weth"]),
            buyAmount2 * 999 / 1000,
            quotes2
        );

        uint256 minAmountOutputToken = ((buyAmount0 + buyAmount1 + buyAmount2) * 999 / 1000);

        deal(address(addyToken), alice, 500e18);
        deal(tokens["ydai"], address(addyToken), requiredQuantities[0]);
        deal(tokens["yusdc"], address(addyToken), requiredQuantities[1]);
        deal(tokens["yusdt"], address(addyToken), requiredQuantities[2]);

        vm.prank(alice);
        IERC20(address(addyToken)).approve(address(tradeIssuer), 500e18);

        vm.prank(alice);
        uint256 totalBaseTokenReturned = tradeIssuer.redeemChamberToNativeToken(
            instructions, addyToken, issuerWizard, minAmountOutputToken, 500e18
        );

        assertEq(addyToken.balanceOf(alice), 0);
        assertEq(addyToken.balanceOf(address(tradeIssuer)), 0);
        assertEq((address(tradeIssuer)).balance, 0);
        assertEq(alice.balance, totalBaseTokenReturned);
        assertGe(alice.balance, minAmountOutputToken);
        console.log("Redeemed Tokens:");
        console.log(totalBaseTokenReturned);
        console.log("Remaining DAI:");
        console.log(IERC20(tokens["dai"]).balanceOf(address(tradeIssuer)));
        console.log("Remaining yDAI:");
        console.log(IERC20(tokens["ydai"]).balanceOf(address(tradeIssuer)));
        console.log("Remaining USDT:");
        console.log(IERC20(tokens["usdt"]).balanceOf(address(tradeIssuer)));
        console.log("Remaining yUSDT:");
        console.log(IERC20(tokens["yusdt"]).balanceOf(address(tradeIssuer)));
        console.log("Remaining USDC:");
        console.log(IERC20(tokens["usdc"]).balanceOf(address(tradeIssuer)));
        console.log("Remaining yUSDC:");
        console.log(IERC20(tokens["yusdc"]).balanceOf(address(tradeIssuer)));
    }
}
