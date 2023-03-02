// Copyright 2023 Smash Works Inc.
// SPDX-License-Identifier: Apache License 2.0
pragma solidity ^0.8.17.0;

import {console} from "forge-std/console.sol";
import {ChamberTestUtils} from "test/utils/ChamberTestUtils.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ChamberGod} from "chambers/ChamberGod.sol";
import {Chamber} from "chambers/Chamber.sol";
import {IssuerWizard} from "chambers/IssuerWizard.sol";
import {IVault} from "src/interfaces/IVault.sol";
import {IChamber} from "chambers/interfaces/IChamber.sol";
import {IIssuerWizard} from "chambers/interfaces/IIssuerWizard.sol";
import {PreciseUnitMath} from "chambers/lib/PreciseUnitMath.sol";
import {TradeIssuerV2} from "src/TradeIssuerV2.sol";
import {ITradeIssuerV2} from "src/interfaces/ITradeIssuerV2.sol";

contract TradeIssuerV2IntegrationMintChamberFromTokenTest is ChamberTestUtils {
    using PreciseUnitMath for uint256;
    using PreciseUnitMath for uint64;

    /*//////////////////////////////////////////////////////////////
                              VARIABLES
    //////////////////////////////////////////////////////////////*/

    TradeIssuerV2 public tradeIssuer;
    ChamberGod public chamberGod = ChamberGod(0x0C9Aa1e4B4E39DA01b7459607995368E4C38cFEF);
    Chamber public addyToken = Chamber(0xE15A66b7B8e385CAa6F69FD0d55984B96D7263CF);
    IssuerWizard public issuerWizard = IssuerWizard(0x60F56236CD3C1Ac146BD94F2006a1335BaA4c449);
    bytes4 public yearnDeposit = bytes4(keccak256("deposit(uint256)"));
    address payable public alice = payable(address(0x1));
    address payable public dexAgg = payable(address(0xDef1C0ded9bec7F1a1670819833240f027b25EfF));
    mapping(string => address) public tokens;
    uint256[] public componentQuantities = new uint256[] (3);

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

        tradeIssuer = new TradeIssuerV2( tokens["weth"]);
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
     * [REVERT] Cannot mint zero chamber amount
     */
    function testCannotMintZeroChamberAmount() public {
        ITradeIssuerV2.ContractCallInstruction[] memory instructions =
            new ITradeIssuerV2.ContractCallInstruction[] (1);

        vm.prank(alice);
        vm.expectRevert(ITradeIssuerV2.ZeroChamberAmount.selector);
        uint256 totalBaseTokenUsed = tradeIssuer.mintChamberFromToken(
            instructions, addyToken, issuerWizard, IERC20(tokens["usdc"]), 1e6, 0
        );
        assertEq(totalBaseTokenUsed, 0);
    }

    /**
     * [REVERT] Cannot mint without input token approval.
     */
    function testCannotMintWithoutBaseTokenApproval() public {
        ITradeIssuerV2.ContractCallInstruction[] memory instructions =
            new ITradeIssuerV2.ContractCallInstruction[] (1);

        deal(tokens["usdc"], alice, 1e6);

        vm.prank(alice);
        vm.expectRevert("ERC20: transfer amount exceeds allowance");
        uint256 totalBaseTokenUsed = tradeIssuer.mintChamberFromToken(
            instructions, addyToken, issuerWizard, IERC20(tokens["usdc"]), 1e6, 1e18
        );
        assertEq(totalBaseTokenUsed, 0);
    }

    /**
     * [REVERT] Cannot mint without input token balance.
     */
    function testCannotMintWithoutBaseTokenBalance() public {
        ITradeIssuerV2.ContractCallInstruction[] memory instructions =
            new ITradeIssuerV2.ContractCallInstruction[] (1);

        vm.prank(alice);
        IERC20(tokens["weth"]).approve(address(tradeIssuer), 1e18);

        vm.prank(alice);
        vm.expectRevert("SafeERC20: low-level call failed");
        uint256 totalBaseTokenUsed = tradeIssuer.mintChamberFromToken(
            instructions, addyToken, issuerWizard, IERC20(tokens["weth"]), 1e18, 1e18
        );
        assertEq(totalBaseTokenUsed, 0);
    }

    /**
     * [REVERT] Cannot mint with underbought asset in an instruction.
     */
    function testCannotMintWithUnderboughtAsset() public {
        ITradeIssuerV2.ContractCallInstruction[] memory instructions =
            new ITradeIssuerV2.ContractCallInstruction[] (1);
        (, uint256[] memory requiredQuantities) =
            issuerWizard.getConstituentsQuantitiesForIssuance(addyToken, 500e18);

        componentQuantities[0] = (
            PreciseUnitMath.preciseMulCeil(1e18, requiredQuantities[0], 18).preciseMulCeil(
                IVault(tokens["ydai"]).pricePerShare(), 18
            )
        ) + 10000;

        uint256 badQuantities = componentQuantities[0] * 10; //requiring 10x the amount of dai that will be bought

        (bytes memory quotes0, uint256 sellAmount0) =
            getQuoteDataForMint(componentQuantities[0], tokens["dai"], tokens["usdc"]);

        instructions[0] = ITradeIssuerV2.ContractCallInstruction(
            dexAgg,
            dexAgg,
            IERC20(tokens["usdc"]),
            sellAmount0,
            IERC20(tokens["dai"]),
            badQuantities,
            quotes0
        );

        uint256 amountWithSlippage = ((sellAmount0) * 101 / 100);

        deal(tokens["usdc"], alice, amountWithSlippage);

        vm.prank(alice);
        IERC20(tokens["usdc"]).approve(address(tradeIssuer), amountWithSlippage);
        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(
                ITradeIssuerV2.UnderboughtAsset.selector, tokens["dai"], badQuantities
            )
        );
        uint256 totalBaseTokenUsed = tradeIssuer.mintChamberFromToken(
            instructions,
            addyToken,
            issuerWizard,
            IERC20(tokens["usdc"]),
            amountWithSlippage,
            500e18
        );
        assertEq(totalBaseTokenUsed, 0);
    }

    /**
     * [REVERT] Cannot mint with bad call data in an instruction.
     */
    function testFailMintWithBadQuoteData() public {
        ITradeIssuerV2.ContractCallInstruction[] memory instructions =
            new ITradeIssuerV2.ContractCallInstruction[] (1);
        (, uint256[] memory requiredQuantities) =
            issuerWizard.getConstituentsQuantitiesForIssuance(addyToken, 500e18);

        componentQuantities[0] = (
            PreciseUnitMath.preciseMulCeil(1e18, requiredQuantities[0], 18).preciseMulCeil(
                IVault(tokens["ydai"]).pricePerShare(), 18
            )
        ) + 10000;

        (, uint256 sellAmount0) =
            getQuoteDataForMint(componentQuantities[0], tokens["dai"], tokens["usdc"]);

        bytes memory badQuotes = bytes("BADQUOTE");

        instructions[0] = ITradeIssuerV2.ContractCallInstruction(
            dexAgg,
            dexAgg,
            IERC20(tokens["usdc"]),
            sellAmount0,
            IERC20(tokens["dai"]),
            componentQuantities[0],
            badQuotes
        );

        uint256 amountWithSlippage = ((sellAmount0) * 101 / 100);

        deal(tokens["usdc"], alice, amountWithSlippage);

        vm.prank(alice);
        IERC20(tokens["usdc"]).approve(address(tradeIssuer), amountWithSlippage);
        vm.prank(alice);
        // It's hard to know why it will revert because the error may change from one target to another.
        uint256 totalBaseTokenUsed = tradeIssuer.mintChamberFromToken(
            instructions,
            addyToken,
            issuerWizard,
            IERC20(tokens["usdc"]),
            amountWithSlippage,
            500e18
        );
        assertEq(totalBaseTokenUsed, 0);
    }

    /**
     * [REVERT] Cannot mint with invalid target in an instruction.
     */
    function testCannotMintWithInvalidTarget() public {
        address payable invalidTarget = payable(address(0x123));

        ITradeIssuerV2.ContractCallInstruction[] memory instructions =
            new ITradeIssuerV2.ContractCallInstruction[] (1);
        (, uint256[] memory requiredQuantities) =
            issuerWizard.getConstituentsQuantitiesForIssuance(addyToken, 500e18);

        componentQuantities[0] = (
            PreciseUnitMath.preciseMulCeil(1e18, requiredQuantities[0], 18).preciseMulCeil(
                IVault(tokens["ydai"]).pricePerShare(), 18
            )
        ) + 10000;

        (bytes memory quotes0, uint256 sellAmount0) =
            getQuoteDataForMint(componentQuantities[0], tokens["dai"], tokens["usdc"]);

        instructions[0] = ITradeIssuerV2.ContractCallInstruction(
            invalidTarget,
            invalidTarget,
            IERC20(tokens["usdc"]),
            sellAmount0,
            IERC20(tokens["dai"]),
            componentQuantities[0],
            quotes0
        );

        uint256 amountWithSlippage = ((sellAmount0) * 101 / 100);

        deal(tokens["usdc"], alice, amountWithSlippage);

        vm.prank(alice);
        IERC20(tokens["usdc"]).approve(address(tradeIssuer), amountWithSlippage);
        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(ITradeIssuerV2.InvalidTarget.selector, invalidTarget)
        );
        uint256 totalBaseTokenUsed = tradeIssuer.mintChamberFromToken(
            instructions,
            addyToken,
            issuerWizard,
            IERC20(tokens["usdc"]),
            amountWithSlippage,
            500e18
        );
        assertEq(totalBaseTokenUsed, 0);
    }

    /**
     * [REVERT] Cannot mint with underbought constituent
     */
    function testCannotMintWithUnderboughtConstituent() public {
        ITradeIssuerV2.ContractCallInstruction[] memory instructions =
            new ITradeIssuerV2.ContractCallInstruction[] (0);

        (address[] memory requiredConstituents, uint256[] memory requiredQuantities) =
            issuerWizard.getConstituentsQuantitiesForIssuance(addyToken, 1e18);

        deal(tokens["usdc"], alice, 1e6);

        vm.prank(alice);
        IERC20(tokens["usdc"]).approve(address(tradeIssuer), 1e6);
        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(
                ITradeIssuerV2.UnderboughtConstituent.selector,
                requiredConstituents[0],
                requiredQuantities[0]
            )
        );
        uint256 totalBaseTokenUsed = tradeIssuer.mintChamberFromToken(
            instructions, addyToken, issuerWizard, IERC20(tokens["usdc"]), 1e6, 1e18
        );
        assertEq(totalBaseTokenUsed, 0);
    }

    /**
     * [REVERT] Cannot mint with overspent input token
     */
    function testCannotMintAddyWithOverSpentUsdc() public {
        ITradeIssuerV2.ContractCallInstruction[] memory instructions =
            new ITradeIssuerV2.ContractCallInstruction[] (5);
        (, uint256[] memory requiredQuantities) =
            issuerWizard.getConstituentsQuantitiesForIssuance(addyToken, 500e18);

        componentQuantities[0] = (
            PreciseUnitMath.preciseMulCeil(1e18, requiredQuantities[0], 18).preciseMulCeil(
                IVault(tokens["ydai"]).pricePerShare(), 18
            )
        ) + 10000;

        componentQuantities[1] = (
            PreciseUnitMath.preciseMulCeil(1e18, requiredQuantities[1], 18).preciseMulCeil(
                IVault(tokens["yusdc"]).pricePerShare(), 6
            )
        ) + 10000;

        componentQuantities[2] = (
            PreciseUnitMath.preciseMulCeil(1e18, requiredQuantities[2], 18).preciseMulCeil(
                IVault(tokens["yusdt"]).pricePerShare(), 6
            )
        ) + 10000;

        (bytes memory quotes0, uint256 sellAmount0) =
            getQuoteDataForMint(componentQuantities[0], tokens["dai"], tokens["usdc"]);
        (bytes memory quotes2, uint256 sellAmount2) =
            getQuoteDataForMint(componentQuantities[2], tokens["usdt"], tokens["usdc"]);

        instructions[0] = ITradeIssuerV2.ContractCallInstruction(
            dexAgg,
            dexAgg,
            IERC20(tokens["usdc"]),
            sellAmount0,
            IERC20(tokens["dai"]),
            componentQuantities[0],
            quotes0
        );

        instructions[1] = ITradeIssuerV2.ContractCallInstruction(
            dexAgg,
            dexAgg,
            IERC20(tokens["usdc"]),
            sellAmount2,
            IERC20(tokens["usdt"]),
            componentQuantities[2],
            quotes2
        );

        instructions[2] = ITradeIssuerV2.ContractCallInstruction(
            payable(tokens["ydai"]),
            tokens["ydai"],
            IERC20(tokens["dai"]),
            componentQuantities[0],
            IERC20(tokens["ydai"]),
            requiredQuantities[0],
            abi.encodeWithSelector(yearnDeposit, componentQuantities[0])
        );

        instructions[3] = ITradeIssuerV2.ContractCallInstruction(
            payable(tokens["yusdc"]),
            tokens["yusdc"],
            IERC20(tokens["usdc"]),
            componentQuantities[1],
            IERC20(tokens["yusdc"]),
            requiredQuantities[1],
            abi.encodeWithSelector(yearnDeposit, componentQuantities[1])
        );

        instructions[4] = ITradeIssuerV2.ContractCallInstruction(
            payable(tokens["yusdt"]),
            tokens["yusdt"],
            IERC20(tokens["usdt"]),
            componentQuantities[2],
            IERC20(tokens["yusdt"]),
            requiredQuantities[2],
            abi.encodeWithSelector(yearnDeposit, componentQuantities[2])
        );

        uint256 amountWithSlippage =
            ((sellAmount0 + componentQuantities[1] + sellAmount2) * 101 / 100);

        deal(tokens["usdc"], address(tradeIssuer), amountWithSlippage);

        vm.prank(alice);
        vm.expectRevert(ITradeIssuerV2.OversoldBaseToken.selector);
        uint256 totalBaseTokenUsed = tradeIssuer.mintChamberFromToken(
            instructions,
            addyToken,
            issuerWizard,
            IERC20(tokens["usdc"]),
            0,
            500e18 // Zero Max Amount to pay
        );

        assertEq(totalBaseTokenUsed, 0);
    }

    /**
     * [REVERT] Cannot mint instructions array with wrong order
     */
    function testCannotMintIwthWrongOrderAtInstructionsArray() public {
        ITradeIssuerV2.ContractCallInstruction[] memory instructions =
            new ITradeIssuerV2.ContractCallInstruction[] (6);
        (, uint256[] memory requiredQuantities) =
            issuerWizard.getConstituentsQuantitiesForIssuance(addyToken, 500e18);

        componentQuantities[0] = (
            PreciseUnitMath.preciseMulCeil(1e18, requiredQuantities[0], 18).preciseMulCeil(
                IVault(tokens["ydai"]).pricePerShare(), 18
            )
        ) + 10000;

        (bytes memory quotes0, uint256 sellAmount0) =
            getQuoteDataForMint(componentQuantities[0], tokens["dai"], tokens["weth"]);

        // Will deposit first before getting the underlying DAI.

        instructions[1] = ITradeIssuerV2.ContractCallInstruction(
            dexAgg,
            dexAgg,
            IERC20(tokens["weth"]),
            sellAmount0,
            IERC20(tokens["dai"]),
            componentQuantities[0],
            quotes0
        );

        instructions[0] = ITradeIssuerV2.ContractCallInstruction(
            payable(tokens["ydai"]),
            tokens["ydai"],
            IERC20(tokens["dai"]),
            componentQuantities[0],
            IERC20(tokens["ydai"]),
            requiredQuantities[0],
            abi.encodeWithSelector(yearnDeposit, componentQuantities[0])
        );

        uint256 amountWithSlippage = ((sellAmount0) * 101 / 100);

        deal(tokens["weth"], alice, amountWithSlippage);

        vm.prank(alice);
        IERC20(tokens["weth"]).approve(address(tradeIssuer), amountWithSlippage);
        vm.prank(alice);
        vm.expectRevert("Address: low-level call failed");
        uint256 totalBaseTokenUsed = tradeIssuer.mintChamberFromToken(
            instructions,
            addyToken,
            issuerWizard,
            IERC20(tokens["weth"]),
            amountWithSlippage,
            500e18
        );

        assertEq(totalBaseTokenUsed, 0);
    }

    /*//////////////////////////////////////////////////////////////
                              SUCCESS
    //////////////////////////////////////////////////////////////*/

    /**
     * [SUCCESS] Mint a chamber token with USDC. In the case of addy, usdc is is the underlying
     * asset of a yearn vault so one less instruction is required.
     */
    function testSuccessMintAddyWithUsdc() public {
        ITradeIssuerV2.ContractCallInstruction[] memory instructions =
            new ITradeIssuerV2.ContractCallInstruction[] (5);
        (, uint256[] memory requiredQuantities) =
            issuerWizard.getConstituentsQuantitiesForIssuance(addyToken, 500e18);

        componentQuantities[0] = (
            PreciseUnitMath.preciseMulCeil(1e18, requiredQuantities[0], 18).preciseMulCeil(
                IVault(tokens["ydai"]).pricePerShare(), 18
            )
        ) + 10000;

        componentQuantities[1] = (
            PreciseUnitMath.preciseMulCeil(1e18, requiredQuantities[1], 18).preciseMulCeil(
                IVault(tokens["yusdc"]).pricePerShare(), 6
            )
        ) + 10000;

        componentQuantities[2] = (
            PreciseUnitMath.preciseMulCeil(1e18, requiredQuantities[2], 18).preciseMulCeil(
                IVault(tokens["yusdt"]).pricePerShare(), 6
            )
        ) + 10000;

        (bytes memory quotes0, uint256 sellAmount0) =
            getQuoteDataForMint(componentQuantities[0], tokens["dai"], tokens["usdc"]);
        (bytes memory quotes2, uint256 sellAmount2) =
            getQuoteDataForMint(componentQuantities[2], tokens["usdt"], tokens["usdc"]);

        instructions[0] = ITradeIssuerV2.ContractCallInstruction(
            dexAgg,
            dexAgg,
            IERC20(tokens["usdc"]),
            sellAmount0,
            IERC20(tokens["dai"]),
            componentQuantities[0],
            quotes0
        );

        instructions[1] = ITradeIssuerV2.ContractCallInstruction(
            dexAgg,
            dexAgg,
            IERC20(tokens["usdc"]),
            sellAmount2,
            IERC20(tokens["usdt"]),
            componentQuantities[2],
            quotes2
        );

        instructions[2] = ITradeIssuerV2.ContractCallInstruction(
            payable(tokens["ydai"]),
            tokens["ydai"],
            IERC20(tokens["dai"]),
            componentQuantities[0],
            IERC20(tokens["ydai"]),
            requiredQuantities[0],
            abi.encodeWithSelector(yearnDeposit, componentQuantities[0])
        );

        instructions[3] = ITradeIssuerV2.ContractCallInstruction(
            payable(tokens["yusdc"]),
            tokens["yusdc"],
            IERC20(tokens["usdc"]),
            componentQuantities[1],
            IERC20(tokens["yusdc"]),
            requiredQuantities[1],
            abi.encodeWithSelector(yearnDeposit, componentQuantities[1])
        );

        instructions[4] = ITradeIssuerV2.ContractCallInstruction(
            payable(tokens["yusdt"]),
            tokens["yusdt"],
            IERC20(tokens["usdt"]),
            componentQuantities[2],
            IERC20(tokens["yusdt"]),
            requiredQuantities[2],
            abi.encodeWithSelector(yearnDeposit, componentQuantities[2])
        );

        uint256 amountWithSlippage =
            ((sellAmount0 + componentQuantities[1] + sellAmount2) * 101 / 100);

        deal(tokens["usdc"], alice, amountWithSlippage);

        vm.prank(alice);
        IERC20(tokens["usdc"]).approve(address(tradeIssuer), amountWithSlippage);
        vm.prank(alice);
        uint256 totalBaseTokenUsed = tradeIssuer.mintChamberFromToken(
            instructions,
            addyToken,
            issuerWizard,
            IERC20(tokens["usdc"]),
            amountWithSlippage,
            500e18
        );

        assertEq(addyToken.balanceOf(alice), 500e18);
        assertEq(addyToken.balanceOf(address(tradeIssuer)), 0);
        assertEq(IERC20(tokens["usdc"]).balanceOf(address(tradeIssuer)), 0);
        assertEq(IERC20(tokens["usdc"]).balanceOf(alice), amountWithSlippage - totalBaseTokenUsed);
        console.log("Mint Cost:");
        console.log(totalBaseTokenUsed);
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
     * [SUCCESS] Mint a chamber token with WETH
     */
    function testSuccessMintAddyWithWeth() public {
        ITradeIssuerV2.ContractCallInstruction[] memory instructions =
            new ITradeIssuerV2.ContractCallInstruction[] (6);
        (, uint256[] memory requiredQuantities) =
            issuerWizard.getConstituentsQuantitiesForIssuance(addyToken, 500e18);

        componentQuantities[0] = (
            PreciseUnitMath.preciseMulCeil(1e18, requiredQuantities[0], 18).preciseMulCeil(
                IVault(tokens["ydai"]).pricePerShare(), 18
            )
        ) + 10000;

        componentQuantities[1] = (
            PreciseUnitMath.preciseMulCeil(1e18, requiredQuantities[1], 18).preciseMulCeil(
                IVault(tokens["yusdc"]).pricePerShare(), 6
            )
        ) + 10000;

        componentQuantities[2] = (
            PreciseUnitMath.preciseMulCeil(1e18, requiredQuantities[2], 18).preciseMulCeil(
                IVault(tokens["yusdt"]).pricePerShare(), 6
            )
        ) + 10000;

        (bytes memory quotes0, uint256 sellAmount0) =
            getQuoteDataForMint(componentQuantities[0], tokens["dai"], tokens["weth"]);
        (bytes memory quotes1, uint256 sellAmount1) =
            getQuoteDataForMint(componentQuantities[1], tokens["usdc"], tokens["weth"]);
        (bytes memory quotes2, uint256 sellAmount2) =
            getQuoteDataForMint(componentQuantities[2], tokens["usdt"], tokens["weth"]);

        instructions[0] = ITradeIssuerV2.ContractCallInstruction(
            dexAgg,
            dexAgg,
            IERC20(tokens["weth"]),
            sellAmount0,
            IERC20(tokens["dai"]),
            componentQuantities[0],
            quotes0
        );

        instructions[1] = ITradeIssuerV2.ContractCallInstruction(
            dexAgg,
            dexAgg,
            IERC20(tokens["weth"]),
            sellAmount1,
            IERC20(tokens["usdc"]),
            componentQuantities[1],
            quotes1
        );

        instructions[2] = ITradeIssuerV2.ContractCallInstruction(
            dexAgg,
            dexAgg,
            IERC20(tokens["weth"]),
            sellAmount2,
            IERC20(tokens["usdt"]),
            componentQuantities[2],
            quotes2
        );

        instructions[3] = ITradeIssuerV2.ContractCallInstruction(
            payable(tokens["ydai"]),
            tokens["ydai"],
            IERC20(tokens["dai"]),
            componentQuantities[0],
            IERC20(tokens["ydai"]),
            requiredQuantities[0],
            abi.encodeWithSelector(yearnDeposit, componentQuantities[0])
        );

        instructions[4] = ITradeIssuerV2.ContractCallInstruction(
            payable(tokens["yusdc"]),
            tokens["yusdc"],
            IERC20(tokens["usdc"]),
            componentQuantities[1],
            IERC20(tokens["yusdc"]),
            requiredQuantities[1],
            abi.encodeWithSelector(yearnDeposit, componentQuantities[1])
        );

        instructions[5] = ITradeIssuerV2.ContractCallInstruction(
            payable(tokens["yusdt"]),
            tokens["yusdt"],
            IERC20(tokens["usdt"]),
            componentQuantities[2],
            IERC20(tokens["yusdt"]),
            requiredQuantities[2],
            abi.encodeWithSelector(yearnDeposit, componentQuantities[2])
        );

        uint256 amountWithSlippage = ((sellAmount0 + sellAmount1 + sellAmount2) * 101 / 100);

        deal(tokens["weth"], alice, amountWithSlippage);

        vm.prank(alice);
        IERC20(tokens["weth"]).approve(address(tradeIssuer), amountWithSlippage);
        vm.prank(alice);
        uint256 totalBaseTokenUsed = tradeIssuer.mintChamberFromToken(
            instructions,
            addyToken,
            issuerWizard,
            IERC20(tokens["weth"]),
            amountWithSlippage,
            500e18
        );

        assertEq(addyToken.balanceOf(alice), 500e18);
        assertEq(addyToken.balanceOf(address(tradeIssuer)), 0);
        assertEq(IERC20(tokens["weth"]).balanceOf(address(tradeIssuer)), 0);
        assertEq(IERC20(tokens["weth"]).balanceOf(alice), amountWithSlippage - totalBaseTokenUsed);
        console.log("Mint Cost:");
        console.log(totalBaseTokenUsed);
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
     * [SUCCESS] Mint a chamber token with WETH but in a different valid order of the instructions array
     * as the above test.
     */
    function testSuccessMintAddyWithWethInDifferentOrder() public {
        ITradeIssuerV2.ContractCallInstruction[] memory instructions =
            new ITradeIssuerV2.ContractCallInstruction[] (6);
        (, uint256[] memory requiredQuantities) =
            issuerWizard.getConstituentsQuantitiesForIssuance(addyToken, 500e18);

        componentQuantities[0] = (
            PreciseUnitMath.preciseMulCeil(1e18, requiredQuantities[0], 18).preciseMulCeil(
                IVault(tokens["ydai"]).pricePerShare(), 18
            )
        ) + 10000;

        componentQuantities[1] = (
            PreciseUnitMath.preciseMulCeil(1e18, requiredQuantities[1], 18).preciseMulCeil(
                IVault(tokens["yusdc"]).pricePerShare(), 6
            )
        ) + 10000;

        componentQuantities[2] = (
            PreciseUnitMath.preciseMulCeil(1e18, requiredQuantities[2], 18).preciseMulCeil(
                IVault(tokens["yusdt"]).pricePerShare(), 6
            )
        ) + 10000;

        (bytes memory quotes0, uint256 sellAmount0) =
            getQuoteDataForMint(componentQuantities[0], tokens["dai"], tokens["weth"]);
        (bytes memory quotes1, uint256 sellAmount1) =
            getQuoteDataForMint(componentQuantities[1], tokens["usdc"], tokens["weth"]);
        (bytes memory quotes2, uint256 sellAmount2) =
            getQuoteDataForMint(componentQuantities[2], tokens["usdt"], tokens["weth"]);

        instructions[0] = ITradeIssuerV2.ContractCallInstruction(
            dexAgg,
            dexAgg,
            IERC20(tokens["weth"]),
            sellAmount0,
            IERC20(tokens["dai"]),
            componentQuantities[0],
            quotes0
        );

        instructions[2] = ITradeIssuerV2.ContractCallInstruction(
            dexAgg,
            dexAgg,
            IERC20(tokens["weth"]),
            sellAmount1,
            IERC20(tokens["usdc"]),
            componentQuantities[1],
            quotes1
        );

        instructions[4] = ITradeIssuerV2.ContractCallInstruction(
            dexAgg,
            dexAgg,
            IERC20(tokens["weth"]),
            sellAmount2,
            IERC20(tokens["usdt"]),
            componentQuantities[2],
            quotes2
        );

        instructions[1] = ITradeIssuerV2.ContractCallInstruction(
            payable(tokens["ydai"]),
            tokens["ydai"],
            IERC20(tokens["dai"]),
            componentQuantities[0],
            IERC20(tokens["ydai"]),
            requiredQuantities[0],
            abi.encodeWithSelector(yearnDeposit, componentQuantities[0])
        );

        instructions[3] = ITradeIssuerV2.ContractCallInstruction(
            payable(tokens["yusdc"]),
            tokens["yusdc"],
            IERC20(tokens["usdc"]),
            componentQuantities[1],
            IERC20(tokens["yusdc"]),
            requiredQuantities[1],
            abi.encodeWithSelector(yearnDeposit, componentQuantities[1])
        );

        instructions[5] = ITradeIssuerV2.ContractCallInstruction(
            payable(tokens["yusdt"]),
            tokens["yusdt"],
            IERC20(tokens["usdt"]),
            componentQuantities[2],
            IERC20(tokens["yusdt"]),
            requiredQuantities[2],
            abi.encodeWithSelector(yearnDeposit, componentQuantities[2])
        );

        uint256 amountWithSlippage = ((sellAmount0 + sellAmount1 + sellAmount2) * 101 / 100);

        deal(tokens["weth"], alice, amountWithSlippage);

        vm.prank(alice);
        IERC20(tokens["weth"]).approve(address(tradeIssuer), amountWithSlippage);
        vm.prank(alice);
        uint256 totalBaseTokenUsed = tradeIssuer.mintChamberFromToken(
            instructions,
            addyToken,
            issuerWizard,
            IERC20(tokens["weth"]),
            amountWithSlippage,
            500e18
        );

        assertEq(addyToken.balanceOf(alice), 500e18);
        assertEq(addyToken.balanceOf(address(tradeIssuer)), 0);
        assertEq(IERC20(tokens["weth"]).balanceOf(address(tradeIssuer)), 0);
        assertEq(IERC20(tokens["weth"]).balanceOf(alice), amountWithSlippage - totalBaseTokenUsed);
        console.log("Mint Cost:");
        console.log(totalBaseTokenUsed);
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
     * [SUCCESS] Mint a chamber token with overbought asset
     */
    function testSuccessMintAddyWithOverboughtUsdt() public {
        ITradeIssuerV2.ContractCallInstruction[] memory instructions =
            new ITradeIssuerV2.ContractCallInstruction[] (6);
        (, uint256[] memory requiredQuantities) =
            issuerWizard.getConstituentsQuantitiesForIssuance(addyToken, 500e18);

        componentQuantities[0] = (
            PreciseUnitMath.preciseMulCeil(1e18, requiredQuantities[0], 18).preciseMulCeil(
                IVault(tokens["ydai"]).pricePerShare(), 18
            )
        ) + 10000;

        componentQuantities[1] = (
            PreciseUnitMath.preciseMulCeil(1e18, requiredQuantities[1], 18).preciseMulCeil(
                IVault(tokens["yusdc"]).pricePerShare(), 6
            )
        ) + 10000;

        componentQuantities[2] = (
            PreciseUnitMath.preciseMulCeil(1e18, requiredQuantities[2], 18).preciseMulCeil(
                IVault(tokens["yusdt"]).pricePerShare(), 6
            )
        ) + 10000;

        (bytes memory quotes0, uint256 sellAmount0) =
            getQuoteDataForMint(componentQuantities[0], tokens["dai"], tokens["weth"]);
        (bytes memory quotes1, uint256 sellAmount1) =
            getQuoteDataForMint(componentQuantities[1], tokens["usdc"], tokens["weth"]);
        (bytes memory quotes2, uint256 sellAmount2) =
            getQuoteDataForMint(componentQuantities[2] * 10, tokens["usdt"], tokens["weth"]); // requiring 10x the usdt amount

        instructions[0] = ITradeIssuerV2.ContractCallInstruction(
            dexAgg,
            dexAgg,
            IERC20(tokens["weth"]),
            sellAmount0,
            IERC20(tokens["dai"]),
            componentQuantities[0],
            quotes0
        );

        instructions[1] = ITradeIssuerV2.ContractCallInstruction(
            dexAgg,
            dexAgg,
            IERC20(tokens["weth"]),
            sellAmount1,
            IERC20(tokens["usdc"]),
            componentQuantities[1],
            quotes1
        );

        instructions[2] = ITradeIssuerV2.ContractCallInstruction(
            dexAgg,
            dexAgg,
            IERC20(tokens["weth"]),
            sellAmount2,
            IERC20(tokens["usdt"]),
            componentQuantities[2],
            quotes2
        );

        instructions[3] = ITradeIssuerV2.ContractCallInstruction(
            payable(tokens["ydai"]),
            tokens["ydai"],
            IERC20(tokens["dai"]),
            componentQuantities[0],
            IERC20(tokens["ydai"]),
            requiredQuantities[0],
            abi.encodeWithSelector(yearnDeposit, componentQuantities[0])
        );

        instructions[4] = ITradeIssuerV2.ContractCallInstruction(
            payable(tokens["yusdc"]),
            tokens["yusdc"],
            IERC20(tokens["usdc"]),
            componentQuantities[1],
            IERC20(tokens["yusdc"]),
            requiredQuantities[1],
            abi.encodeWithSelector(yearnDeposit, componentQuantities[1])
        );

        instructions[5] = ITradeIssuerV2.ContractCallInstruction(
            payable(tokens["yusdt"]),
            tokens["yusdt"],
            IERC20(tokens["usdt"]),
            componentQuantities[2],
            IERC20(tokens["yusdt"]),
            requiredQuantities[2],
            abi.encodeWithSelector(yearnDeposit, componentQuantities[2])
        );

        uint256 amountWithSlippage = ((sellAmount0 + sellAmount1 + sellAmount2) * 101 / 100);

        deal(tokens["weth"], alice, amountWithSlippage);

        vm.prank(alice);
        IERC20(tokens["weth"]).approve(address(tradeIssuer), amountWithSlippage);
        vm.prank(alice);
        uint256 totalBaseTokenUsed = tradeIssuer.mintChamberFromToken(
            instructions,
            addyToken,
            issuerWizard,
            IERC20(tokens["weth"]),
            amountWithSlippage,
            500e18
        );

        assertEq(addyToken.balanceOf(alice), 500e18);
        assertEq(addyToken.balanceOf(address(tradeIssuer)), 0);
        assertEq(IERC20(tokens["weth"]).balanceOf(address(tradeIssuer)), 0);
        assertEq(IERC20(tokens["weth"]).balanceOf(alice), amountWithSlippage - totalBaseTokenUsed);
        assertGt(IERC20(tokens["usdt"]).balanceOf(address(tradeIssuer)), componentQuantities[2] * 9);
        console.log("Mint Cost:");
        console.log(totalBaseTokenUsed);
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
