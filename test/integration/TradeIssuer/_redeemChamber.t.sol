// Copyright 2022 Smash Works Inc.
// SPDX-License-Identifier: Apache License 2.0
pragma solidity ^0.8.17.0;

import {ChamberTestUtils} from "test/utils/ChamberTestUtils.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Chamber} from "chambers/Chamber.sol";
import {ChamberFactory} from "test/utils/factories.sol";
import {IssuerWizard} from "chambers/IssuerWizard.sol";
import {IVault} from "src/interfaces/IVault.sol";
import {IChamber} from "chambers/interfaces/IChamber.sol";
import {IIssuerWizard} from "chambers/interfaces/IIssuerWizard.sol";
import {PreciseUnitMath} from "chambers/lib/PreciseUnitMath.sol";
import {ExposedTradeIssuer} from "test/utils/ExposedTradeIssuer.sol";
import {ITradeIssuer} from "src/interfaces/ITradeIssuer.sol";

contract TradeIssuerIntegrationInternalRedeemChamberTest is ChamberTestUtils {
    using PreciseUnitMath for uint256;
    using PreciseUnitMath for uint64;

    /*//////////////////////////////////////////////////////////////
                              VARIABLES
    //////////////////////////////////////////////////////////////*/

    ExposedTradeIssuer public tradeIssuer;
    ChamberFactory public chamberFactory;
    Chamber public baseChamber;
    IssuerWizard public issuerWizard;
    mapping(string => address) public tokens;
    address payable public dexAgg = payable(address(0xDef1C0ded9bec7F1a1670819833240f027b25EfF));
    address public tradeIssuerAddress;
    address payable public alice = payable(address(0x12345e6));
    uint256[] public componentQuantities = new uint256[] (2);
    uint256[] public vaultQuantities = new uint256[](2);
    uint256[] public baseQuantities = new uint256[] (2);
    address[] public components = new address[] (2);
    address[] public baseConstituents = new address[](2);
    address[] public vaults = new address[](2);
    address[] public vaultAssets = new address[](2);
    bytes[] public quotes = new bytes[](2);

    /*//////////////////////////////////////////////////////////////
                              SET UP
    //////////////////////////////////////////////////////////////*/

    function setUp() public {
        tokens["weth"] = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
        tokens["usdc"] = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
        tokens["dai"] = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
        tokens["yusdc"] = 0xa354F35829Ae975e850e23e9615b11Da1B3dC4DE;
        tokens["ydai"] = 0xdA816459F1AB5631232FE5e97a05BBBb94970c95;
        tokens["yfi"] = 0x0bc529c00C6401aEF6D220BE8C6Ea1667F6Ad93e;

        tradeIssuer = new ExposedTradeIssuer(dexAgg, tokens["weth"]);
        tradeIssuerAddress = address(tradeIssuer);
        vm.label(address(tradeIssuer), "TradeIssuer");

        issuerWizard = new IssuerWizard();

        vaults[0] = tokens["yusdc"];
        vaults[1] = tokens["ydai"];
        vaultAssets[0] = tokens["usdc"];
        vaultAssets[1] = tokens["dai"];

        baseConstituents[0] = tokens["yusdc"];
        baseConstituents[1] = tokens["dai"];
        baseQuantities[0] = 20e6;
        baseQuantities[1] = 20e18;

        address[] memory wizards = new address[](1);
        wizards[0] = address(issuerWizard);
        address[] memory managers = new address[](0);

        chamberFactory = new ChamberFactory(
          address(this),
          "name",
          "symbol",
          wizards,
          managers
        );

        baseChamber = chamberFactory.getChamberWithCustomTokens(baseConstituents, baseQuantities);

        vm.label(vm.addr(0x791782394), "ChamberGod");
        vm.label(address(issuerWizard), "IssuerWizard");
        vm.label(address(chamberFactory), "ChamberFactory");
        vm.label(dexAgg, "ZeroEx");
        vm.label(alice, "Alice");
        vm.label(tokens["weth"], "WETH");
        vm.label(tokens["usdc"], "USDC");
        vm.label(tokens["dai"], "DAI");
        vm.label(tokens["yusdc"], "yUSDC");
        vm.label(tokens["ydai"], "yDAI");
        vm.label(tokens["yfi"], "YFI");
    }

    /*//////////////////////////////////////////////////////////////
                              REVERT
    //////////////////////////////////////////////////////////////*/

    /**
     * [REVERT] Cannot redeem if trader uses a quote that sells less than the slippage
     * allowed for a token. i.e A token is undersold in dex.
     */
    function testCannotRedeemIfUndersoldAsset() public {
        // Mint some amount to alice
        vaultAssets = new address[](1);
        vaults = new address[](1);
        vaultQuantities = new uint256[](1);

        baseConstituents[0] = tokens["yusdc"];
        baseConstituents[1] = tokens["dai"];
        components[0] = tokens["usdc"];
        components[1] = tokens["dai"];
        vaultAssets[0] = tokens["usdc"];
        vaults[0] = tokens["yusdc"];

        baseChamber = chamberFactory.getChamberWithCustomTokens(baseConstituents, baseQuantities);

        componentQuantities[0] = (
            PreciseUnitMath.preciseMulCeil(1e18, baseQuantities[0], 18).preciseMulCeil(
                IVault(vaults[0]).pricePerShare(), 6
            ) * 1001
        ) / 1000;
        componentQuantities[1] = PreciseUnitMath.preciseMulCeil(1e18, baseQuantities[1], 18);

        vaultQuantities[0] = componentQuantities[0];

        (bytes memory quotes0, uint256 sellAmount0) =
            getQuoteDataForMint(componentQuantities[0], tokens["usdc"], tokens["weth"]);
        (bytes memory quotes1, uint256 sellAmount1) =
            getQuoteDataForMint(componentQuantities[1], tokens["dai"], tokens["weth"]);
        quotes[0] = quotes0;
        quotes[1] = quotes1;

        uint256 amountWithSlippage = ((sellAmount0 + sellAmount1) * 101 / 100);

        deal(tokens["weth"], alice, amountWithSlippage);

        vm.prank(alice);
        IERC20(tokens["weth"]).approve(address(tradeIssuer), amountWithSlippage);

        vm.prank(alice);
        uint256 totalNativeTokenUsed = tradeIssuer.mintChamberFromToken(
            ITradeIssuer.IssuanceParams(
                quotes,
                IERC20(tokens["weth"]),
                amountWithSlippage,
                1e18,
                IChamber(address(baseChamber)),
                IIssuerWizard(address(issuerWizard)),
                components,
                componentQuantities,
                vaults,
                vaultAssets,
                vaultQuantities,
                5
            )
        );
        assertEq(totalNativeTokenUsed, amountWithSlippage - IERC20(tokens["weth"]).balanceOf(alice));
        assertEq(IERC20(address(baseChamber)).totalSupply(), 1e18);

        // Now redeem

        // Calcualte quantities to sell
        componentQuantities[0] = (
            PreciseUnitMath.preciseMulCeil(
                ERC20(address(baseChamber)).balanceOf(alice), baseQuantities[0], 18
            ).preciseMulCeil(IVault(vaults[0]).pricePerShare(), 6)
        );

        componentQuantities[1] = PreciseUnitMath.preciseMulCeil(
            ERC20(address(baseChamber)).balanceOf(alice), baseQuantities[1], 18
        );

        vaultQuantities[0] = PreciseUnitMath.preciseMulCeil(
            ERC20(address(baseChamber)).balanceOf(alice), baseQuantities[0], 18
        );

        // Ask for quote, quote 00 tries to sell half the amount
        (bytes memory quotes00,) =
            getQuoteDataForRedeem(componentQuantities[0] / 2, tokens["usdc"], tokens["weth"]);
        (bytes memory quotes11,) =
            getQuoteDataForRedeem(componentQuantities[1], tokens["dai"], tokens["weth"]);

        quotes[0] = quotes00;
        quotes[1] = quotes11;

        vm.prank(alice);
        ERC20(address(baseChamber)).transfer(address(tradeIssuer), 1e18);

        assertEq(IERC20(address(baseChamber)).balanceOf(alice), 0);
        assertEq(IERC20(address(baseChamber)).balanceOf(address(tradeIssuer)), 1e18);

        vm.expectRevert("Undersold dex asset");
        vm.prank(alice);
        tradeIssuer.redeemChamber(
            ITradeIssuer.IssuanceParams(
                quotes,
                IERC20(tokens["weth"]),
                0, // Can be any value since it wont be used at redeemChamber
                1e18,
                IChamber(address(baseChamber)),
                IIssuerWizard(address(issuerWizard)),
                components,
                componentQuantities,
                vaults,
                vaultAssets,
                vaultQuantities,
                5
            )
        );

        assertEq(IERC20(address(baseChamber)).balanceOf(alice), 0);
        assertEq(IERC20(address(baseChamber)).balanceOf(address(tradeIssuer)), 1e18);
        assertEq(IERC20(address(baseChamber)).totalSupply(), 1e18);
    }

    /**
     * [REVERT] Cannot redeem if a quote is malformed.
     */
    function testFailRedeemWithMalformedQuote() public {
        // Mint some amount to alice
        vaultAssets = new address[](1);
        vaults = new address[](1);
        vaultQuantities = new uint256[](1);

        baseConstituents[0] = tokens["yusdc"];
        baseConstituents[1] = tokens["dai"];
        components[0] = tokens["usdc"];
        components[1] = tokens["dai"];
        vaultAssets[0] = tokens["usdc"];
        vaults[0] = tokens["yusdc"];

        baseChamber = chamberFactory.getChamberWithCustomTokens(baseConstituents, baseQuantities);

        componentQuantities[0] = (
            PreciseUnitMath.preciseMulCeil(1e18, baseQuantities[0], 18).preciseMulCeil(
                IVault(vaults[0]).pricePerShare(), 6
            ) * 1001
        ) / 1000;
        componentQuantities[1] = PreciseUnitMath.preciseMulCeil(1e18, baseQuantities[1], 18);

        vaultQuantities[0] = componentQuantities[0];

        (bytes memory quotes0, uint256 sellAmount0) =
            getQuoteDataForMint(componentQuantities[0], tokens["usdc"], tokens["weth"]);
        (bytes memory quotes1, uint256 sellAmount1) =
            getQuoteDataForMint(componentQuantities[1], tokens["dai"], tokens["weth"]);
        quotes[0] = quotes0;
        quotes[1] = quotes1;

        uint256 amountWithSlippage = ((sellAmount0 + sellAmount1) * 101 / 100);

        deal(tokens["weth"], alice, amountWithSlippage);

        vm.prank(alice);
        IERC20(tokens["weth"]).approve(address(tradeIssuer), amountWithSlippage);

        vm.prank(alice);
        uint256 totalNativeTokenUsed = tradeIssuer.mintChamberFromToken(
            ITradeIssuer.IssuanceParams(
                quotes,
                IERC20(tokens["weth"]),
                amountWithSlippage,
                1e18,
                IChamber(address(baseChamber)),
                IIssuerWizard(address(issuerWizard)),
                components,
                componentQuantities,
                vaults,
                vaultAssets,
                vaultQuantities,
                5
            )
        );
        assertEq(totalNativeTokenUsed, amountWithSlippage - IERC20(tokens["weth"]).balanceOf(alice));
        assertEq(IERC20(address(baseChamber)).totalSupply(), 1e18);

        // Now redeem

        // Calcualte quantities to sell
        componentQuantities[0] = (
            PreciseUnitMath.preciseMulCeil(
                ERC20(address(baseChamber)).balanceOf(alice), baseQuantities[0], 18
            ).preciseMulCeil(IVault(vaults[0]).pricePerShare(), 6)
        );

        componentQuantities[1] = PreciseUnitMath.preciseMulCeil(
            ERC20(address(baseChamber)).balanceOf(alice), baseQuantities[1], 18
        );

        vaultQuantities[0] = PreciseUnitMath.preciseMulCeil(
            ERC20(address(baseChamber)).balanceOf(alice), baseQuantities[0], 18
        );

        (bytes memory quotes00,) =
            getQuoteDataForRedeem(componentQuantities[0], tokens["usdc"], tokens["weth"]);

        quotes[0] = quotes00;
        quotes[1] = bytes("BAD-DEX-QUOTE");

        vm.prank(alice);
        ERC20(address(baseChamber)).transfer(address(tradeIssuer), 1e18);

        assertEq(IERC20(address(baseChamber)).balanceOf(alice), 0);
        assertEq(IERC20(address(baseChamber)).balanceOf(address(tradeIssuer)), 1e18);

        vm.prank(alice);
        tradeIssuer.redeemChamber(
            ITradeIssuer.IssuanceParams(
                quotes,
                IERC20(tokens["weth"]),
                0, // Can be any value since it wont be used at redeemChamber
                1e18,
                IChamber(address(baseChamber)),
                IIssuerWizard(address(issuerWizard)),
                components,
                componentQuantities,
                vaults,
                vaultAssets,
                vaultQuantities,
                5
            )
        );

        assertEq(IERC20(address(baseChamber)).balanceOf(alice), 0);
        assertEq(IERC20(address(baseChamber)).balanceOf(address(tradeIssuer)), 1e18);
        assertEq(IERC20(address(baseChamber)).totalSupply(), 1e18);
    }

    /**
     * [REVERT] Cannot redeem if a quantity is zero.
     */
    function testCannotRedeemWithAZeroQuantity() public {
        // Mint some amount to alice
        vaultAssets = new address[](1);
        vaults = new address[](1);
        vaultQuantities = new uint256[](1);

        baseConstituents[0] = tokens["yusdc"];
        baseConstituents[1] = tokens["dai"];
        components[0] = tokens["usdc"];
        components[1] = tokens["dai"];
        vaultAssets[0] = tokens["usdc"];
        vaults[0] = tokens["yusdc"];

        baseChamber = chamberFactory.getChamberWithCustomTokens(baseConstituents, baseQuantities);

        componentQuantities[0] = (
            PreciseUnitMath.preciseMulCeil(1e18, baseQuantities[0], 18).preciseMulCeil(
                IVault(vaults[0]).pricePerShare(), 6
            ) * 1001
        ) / 1000;
        componentQuantities[1] = PreciseUnitMath.preciseMulCeil(1e18, baseQuantities[1], 18);

        vaultQuantities[0] = componentQuantities[0];

        (bytes memory quotes0, uint256 sellAmount0) =
            getQuoteDataForMint(componentQuantities[0], tokens["usdc"], tokens["weth"]);
        (bytes memory quotes1, uint256 sellAmount1) =
            getQuoteDataForMint(componentQuantities[1], tokens["dai"], tokens["weth"]);
        quotes[0] = quotes0;
        quotes[1] = quotes1;

        uint256 amountWithSlippage = ((sellAmount0 + sellAmount1) * 101 / 100);

        deal(tokens["weth"], alice, amountWithSlippage);

        vm.prank(alice);
        IERC20(tokens["weth"]).approve(address(tradeIssuer), amountWithSlippage);

        vm.prank(alice);
        uint256 totalNativeTokenUsed = tradeIssuer.mintChamberFromToken(
            ITradeIssuer.IssuanceParams(
                quotes,
                IERC20(tokens["weth"]),
                amountWithSlippage,
                1e18,
                IChamber(address(baseChamber)),
                IIssuerWizard(address(issuerWizard)),
                components,
                componentQuantities,
                vaults,
                vaultAssets,
                vaultQuantities,
                5
            )
        );
        assertEq(totalNativeTokenUsed, amountWithSlippage - IERC20(tokens["weth"]).balanceOf(alice));
        assertEq(IERC20(address(baseChamber)).totalSupply(), 1e18);

        // Now redeem

        // Calcualte quantities to sell
        componentQuantities[0] = PreciseUnitMath.preciseMulCeil(
            ERC20(address(baseChamber)).balanceOf(alice), baseQuantities[0], 18
        );

        componentQuantities[1] = PreciseUnitMath.preciseMulCeil(
            ERC20(address(baseChamber)).balanceOf(alice), baseQuantities[1], 18
        );

        vaultQuantities[0] = PreciseUnitMath.preciseMulCeil(
            ERC20(address(baseChamber)).balanceOf(alice), baseQuantities[0], 18
        );

        // Ask for quote
        (bytes memory quotes00,) =
            getQuoteDataForRedeem(componentQuantities[0], tokens["usdc"], tokens["weth"]);
        (bytes memory quotes11,) =
            getQuoteDataForRedeem(componentQuantities[1], tokens["dai"], tokens["weth"]);

        quotes[0] = quotes00;
        quotes[1] = quotes11;

        componentQuantities[0] = 0;
        vm.prank(alice);
        ERC20(address(baseChamber)).transfer(address(tradeIssuer), 1e18);

        assertEq(IERC20(address(baseChamber)).balanceOf(alice), 0);
        assertEq(IERC20(address(baseChamber)).balanceOf(address(tradeIssuer)), 1e18);

        // Redeem
        uint256 previousTraderBalance =
            IERC20(address(tokens["weth"])).balanceOf(address(tradeIssuer));

        vm.expectRevert("Cannot sell zero tokens");

        vm.prank(alice);
        uint256 totalWETHReceived = tradeIssuer.redeemChamber(
            ITradeIssuer.IssuanceParams(
                quotes,
                IERC20(tokens["weth"]),
                0, // Can be any value since it wont be used at redeemChamber
                1e18,
                IChamber(address(baseChamber)),
                IIssuerWizard(address(issuerWizard)),
                components,
                componentQuantities,
                vaults,
                vaultAssets,
                vaultQuantities,
                5
            )
        );

        assertEq(
            IERC20(address(tokens["weth"])).balanceOf(address(tradeIssuer)),
            previousTraderBalance + totalWETHReceived
        );
        assertEq(IERC20(address(baseChamber)).balanceOf(alice), 0);
        assertEq(IERC20(address(baseChamber)).balanceOf(address(tradeIssuer)), 1e18);
        assertEq(IERC20(address(baseChamber)).totalSupply(), 1e18);
    }

    /**
     * [REVERT] Cannot redeem with empty components even if quantities and quotes
     * have the same length.
     */
    function testCannotRedeemWithEmptyQuantitiesQuotesAndComponents() public {
        // Mint some amount to alice
        vaultAssets = new address[](1);
        vaults = new address[](1);
        vaultQuantities = new uint256[](1);

        baseConstituents[0] = tokens["yusdc"];
        baseConstituents[1] = tokens["dai"];
        components[0] = tokens["usdc"];
        components[1] = tokens["dai"];
        vaultAssets[0] = tokens["usdc"];
        vaults[0] = tokens["yusdc"];

        baseChamber = chamberFactory.getChamberWithCustomTokens(baseConstituents, baseQuantities);

        componentQuantities[0] = (
            PreciseUnitMath.preciseMulCeil(1e18, baseQuantities[0], 18).preciseMulCeil(
                IVault(vaults[0]).pricePerShare(), 6
            ) * 1001
        ) / 1000;
        componentQuantities[1] = PreciseUnitMath.preciseMulCeil(1e18, baseQuantities[1], 18);

        vaultQuantities[0] = componentQuantities[0];

        (bytes memory quotes0, uint256 sellAmount0) =
            getQuoteDataForMint(componentQuantities[0], tokens["usdc"], tokens["weth"]);
        (bytes memory quotes1, uint256 sellAmount1) =
            getQuoteDataForMint(componentQuantities[1], tokens["dai"], tokens["weth"]);
        quotes[0] = quotes0;
        quotes[1] = quotes1;

        uint256 amountWithSlippage = ((sellAmount0 + sellAmount1) * 101 / 100);

        deal(tokens["weth"], alice, amountWithSlippage);

        vm.prank(alice);
        IERC20(tokens["weth"]).approve(address(tradeIssuer), amountWithSlippage);

        vm.prank(alice);
        uint256 totalNativeTokenUsed = tradeIssuer.mintChamberFromToken(
            ITradeIssuer.IssuanceParams(
                quotes,
                IERC20(tokens["weth"]),
                amountWithSlippage,
                1e18,
                IChamber(address(baseChamber)),
                IIssuerWizard(address(issuerWizard)),
                components,
                componentQuantities,
                vaults,
                vaultAssets,
                vaultQuantities,
                5
            )
        );
        assertEq(totalNativeTokenUsed, amountWithSlippage - IERC20(tokens["weth"]).balanceOf(alice));
        assertEq(IERC20(address(baseChamber)).totalSupply(), 1e18);

        // Now redeem

        // Calculate quantities to sell
        address[] memory emptyComponents = new address[] (0);
        uint256[] memory emptyQuantities = new uint256[] (0);
        bytes[] memory emptyQuotes = new bytes[] (0);

        vaultQuantities[0] = PreciseUnitMath.preciseMulCeil(
            ERC20(address(baseChamber)).balanceOf(alice), baseQuantities[0], 18
        );

        vm.prank(alice);
        ERC20(address(baseChamber)).transfer(address(tradeIssuer), 1e18);

        assertEq(IERC20(address(baseChamber)).balanceOf(alice), 0);
        assertEq(IERC20(address(baseChamber)).balanceOf(address(tradeIssuer)), 1e18);

        // Redeem
        vm.prank(alice);
        vm.expectRevert("Components array cannot be empty");
        tradeIssuer.redeemChamber(
            ITradeIssuer.IssuanceParams(
                emptyQuotes,
                IERC20(tokens["weth"]),
                0, // Can be any value since it wont be used at redeemChamber
                1e18,
                IChamber(address(baseChamber)),
                IIssuerWizard(address(issuerWizard)),
                emptyComponents,
                emptyQuantities,
                vaults,
                vaultAssets,
                vaultQuantities,
                5
            )
        );

        assertEq(IERC20(address(baseChamber)).balanceOf(alice), 0);
        assertEq(IERC20(address(baseChamber)).balanceOf(address(tradeIssuer)), 1e18);
        assertEq(IERC20(address(baseChamber)).totalSupply(), 1e18);
    }

    /**
     * [REVERT] Cannot redeem when there's an nonexistant vault or not compliant with ERC4626.
     */
    function testCannotRedeemWithUnexistingVault() public {
        // Mint some amount to alice
        vaultAssets = new address[](1);
        vaults = new address[](1);
        vaultQuantities = new uint256[](1);
        baseConstituents[0] = tokens["yusdc"];
        baseConstituents[1] = tokens["dai"];
        components[0] = tokens["usdc"];
        components[1] = tokens["dai"];
        vaultAssets[0] = tokens["usdc"];
        vaults[0] = tokens["yusdc"];

        baseChamber = chamberFactory.getChamberWithCustomTokens(baseConstituents, baseQuantities);

        componentQuantities[0] = (
            PreciseUnitMath.preciseMulCeil(1e18, baseQuantities[0], 18).preciseMulCeil(
                IVault(vaults[0]).pricePerShare(), 6
            ) * 1001
        ) / 1000;
        componentQuantities[1] = PreciseUnitMath.preciseMulCeil(1e18, baseQuantities[1], 18);

        vaultQuantities[0] = componentQuantities[0];

        (bytes memory quotes0, uint256 sellAmount0) =
            getQuoteDataForMint(componentQuantities[0], tokens["usdc"], tokens["weth"]);
        (bytes memory quotes1, uint256 sellAmount1) =
            getQuoteDataForMint(componentQuantities[1], tokens["dai"], tokens["weth"]);
        quotes[0] = quotes0;
        quotes[1] = quotes1;

        uint256 amountWithSlippage = ((sellAmount0 + sellAmount1) * 101 / 100);

        deal(tokens["weth"], alice, amountWithSlippage);

        vm.prank(alice);
        IERC20(tokens["weth"]).approve(address(tradeIssuer), amountWithSlippage);

        vm.prank(alice);
        uint256 totalNativeTokenUsed = tradeIssuer.mintChamberFromToken(
            ITradeIssuer.IssuanceParams(
                quotes,
                IERC20(tokens["weth"]),
                amountWithSlippage,
                1e18,
                IChamber(address(baseChamber)),
                IIssuerWizard(address(issuerWizard)),
                components,
                componentQuantities,
                vaults,
                vaultAssets,
                vaultQuantities,
                5
            )
        );
        assertEq(totalNativeTokenUsed, amountWithSlippage - IERC20(tokens["weth"]).balanceOf(alice));
        assertEq(IERC20(address(baseChamber)).totalSupply(), 1e18);

        // Now redeem

        // Calcualte quantities to sell
        componentQuantities[0] = (
            PreciseUnitMath.preciseMulCeil(
                ERC20(address(baseChamber)).balanceOf(alice), baseQuantities[0], 18
            ).preciseMulCeil(IVault(vaults[0]).pricePerShare(), 6)
        );

        componentQuantities[1] = PreciseUnitMath.preciseMulCeil(
            ERC20(address(baseChamber)).balanceOf(alice), baseQuantities[1], 18
        );

        vaultQuantities[0] = PreciseUnitMath.preciseMulCeil(
            ERC20(address(baseChamber)).balanceOf(alice), baseQuantities[0], 18
        );

        // Ask for quote
        (bytes memory quotes00,) =
            getQuoteDataForRedeem(componentQuantities[0], tokens["usdc"], tokens["weth"]);
        (bytes memory quotes11,) =
            getQuoteDataForRedeem(componentQuantities[1], tokens["dai"], tokens["weth"]);

        quotes[0] = quotes00;
        quotes[1] = quotes11;

        vaults[0] = address(0x12345);

        vm.prank(alice);
        ERC20(address(baseChamber)).transfer(address(tradeIssuer), 1e18);

        assertEq(IERC20(address(baseChamber)).balanceOf(alice), 0);
        assertEq(IERC20(address(baseChamber)).balanceOf(address(tradeIssuer)), 1e18);

        // Redeem
        uint256 previousTraderBalance =
            IERC20(address(tokens["weth"])).balanceOf(address(tradeIssuer));

        vm.expectRevert("Quantity is zero");
        vm.prank(alice);
        uint256 totalWETHReceived = tradeIssuer.redeemChamber(
            ITradeIssuer.IssuanceParams(
                quotes,
                IERC20(tokens["weth"]),
                0, // Can be any value since it wont be used at redeemChamber
                1e18,
                IChamber(address(baseChamber)),
                IIssuerWizard(address(issuerWizard)),
                components,
                componentQuantities,
                vaults,
                vaultAssets,
                vaultQuantities,
                5
            )
        );

        assertEq(
            IERC20(address(tokens["weth"])).balanceOf(address(tradeIssuer)),
            previousTraderBalance + totalWETHReceived
        );
        assertEq(IERC20(address(baseChamber)).balanceOf(alice), 0);
        assertEq(IERC20(address(baseChamber)).balanceOf(address(tradeIssuer)), 1e18);
        assertEq(IERC20(address(baseChamber)).totalSupply(), 1e18);
    }

    /**
     * [REVERT] Cannot redeem ERC20 that doesn't exist.
     */
    function testFailRedeemWithUnexistingERC20AsOutputToken() public {
        // Mint some amount to alice
        vaultAssets = new address[](1);
        vaults = new address[](1);
        vaultQuantities = new uint256[](1);

        baseConstituents[0] = tokens["yusdc"];
        baseConstituents[1] = tokens["dai"];
        components[0] = tokens["usdc"];
        components[1] = tokens["dai"];
        vaultAssets[0] = tokens["usdc"];
        vaults[0] = tokens["yusdc"];

        baseChamber = chamberFactory.getChamberWithCustomTokens(baseConstituents, baseQuantities);

        componentQuantities[0] = (
            PreciseUnitMath.preciseMulCeil(1e18, baseQuantities[0], 18).preciseMulCeil(
                IVault(vaults[0]).pricePerShare(), 6
            ) * 1001
        ) / 1000;
        componentQuantities[1] = PreciseUnitMath.preciseMulCeil(1e18, baseQuantities[1], 18);

        vaultQuantities[0] = componentQuantities[0];

        (bytes memory quotes0, uint256 sellAmount0) =
            getQuoteDataForMint(componentQuantities[0], tokens["usdc"], tokens["weth"]);
        (bytes memory quotes1, uint256 sellAmount1) =
            getQuoteDataForMint(componentQuantities[1], tokens["dai"], tokens["weth"]);
        quotes[0] = quotes0;
        quotes[1] = quotes1;

        uint256 amountWithSlippage = ((sellAmount0 + sellAmount1) * 101 / 100);

        deal(tokens["weth"], alice, amountWithSlippage);

        vm.prank(alice);
        IERC20(tokens["weth"]).approve(address(tradeIssuer), amountWithSlippage);

        vm.prank(alice);
        uint256 totalNativeTokenUsed = tradeIssuer.mintChamberFromToken(
            ITradeIssuer.IssuanceParams(
                quotes,
                IERC20(tokens["weth"]),
                amountWithSlippage,
                1e18,
                IChamber(address(baseChamber)),
                IIssuerWizard(address(issuerWizard)),
                components,
                componentQuantities,
                vaults,
                vaultAssets,
                vaultQuantities,
                5
            )
        );
        assertEq(totalNativeTokenUsed, amountWithSlippage - IERC20(tokens["weth"]).balanceOf(alice));
        assertEq(IERC20(address(baseChamber)).totalSupply(), 1e18);

        // Now redeem

        // Calcualte quantities to sell
        componentQuantities[0] = (
            PreciseUnitMath.preciseMulCeil(
                ERC20(address(baseChamber)).balanceOf(alice), baseQuantities[0], 18
            ).preciseMulCeil(IVault(vaults[0]).pricePerShare(), 6)
        );

        componentQuantities[1] = PreciseUnitMath.preciseMulCeil(
            ERC20(address(baseChamber)).balanceOf(alice), baseQuantities[1], 18
        );

        vaultQuantities[0] = PreciseUnitMath.preciseMulCeil(
            ERC20(address(baseChamber)).balanceOf(alice), baseQuantities[0], 18
        );

        // Ask for quote
        (bytes memory quotes00,) =
            getQuoteDataForRedeem(componentQuantities[0], tokens["usdc"], tokens["weth"]);
        (bytes memory quotes11,) =
            getQuoteDataForRedeem(componentQuantities[1], tokens["dai"], tokens["weth"]);

        quotes[0] = quotes00;
        quotes[1] = quotes11;

        vm.prank(alice);
        ERC20(address(baseChamber)).transfer(address(tradeIssuer), 1e18);

        assertEq(IERC20(address(baseChamber)).balanceOf(alice), 0);
        assertEq(IERC20(address(baseChamber)).balanceOf(address(tradeIssuer)), 1e18);

        // Redeem
        uint256 previousTraderBalance =
            IERC20(address(tokens["weth"])).balanceOf(address(tradeIssuer));
        vm.prank(alice);
        uint256 totalWETHReceived = tradeIssuer.redeemChamber(
            ITradeIssuer.IssuanceParams(
                quotes,
                IERC20(address(0x123456)),
                0, // Can be any value since it wont be used at redeemChamber
                1e18,
                IChamber(address(baseChamber)),
                IIssuerWizard(address(issuerWizard)),
                components,
                componentQuantities,
                vaults,
                vaultAssets,
                vaultQuantities,
                5
            )
        );

        assertEq(
            IERC20(address(tokens["weth"])).balanceOf(address(tradeIssuer)),
            previousTraderBalance + totalWETHReceived
        );
        assertEq(IERC20(address(baseChamber)).balanceOf(alice), 0);
        assertEq(IERC20(address(baseChamber)).totalSupply(), 0);
        assertEq(IERC20(address(baseConstituents[0])).balanceOf(address(baseChamber)), 0);
        assertEq(IERC20(address(baseConstituents[1])).balanceOf(address(baseChamber)), 0);
    }

    /*//////////////////////////////////////////////////////////////
                              SUCCESS
    //////////////////////////////////////////////////////////////*/

    /**
     * [SUCCESS] Can redeem chamber that has both ERC20 and Vault assets, for WETH.
     */
    function testRedeemVaultAndERC20Assets() public {
        // Mint some amount to alice
        vaultAssets = new address[](1);
        vaults = new address[](1);
        vaultQuantities = new uint256[](1);

        baseConstituents[0] = tokens["yusdc"];
        baseConstituents[1] = tokens["dai"];
        components[0] = tokens["usdc"];
        components[1] = tokens["dai"];
        vaultAssets[0] = tokens["usdc"];
        vaults[0] = tokens["yusdc"];

        baseChamber = chamberFactory.getChamberWithCustomTokens(baseConstituents, baseQuantities);

        componentQuantities[0] = (
            PreciseUnitMath.preciseMulCeil(1e18, baseQuantities[0], 18).preciseMulCeil(
                IVault(vaults[0]).pricePerShare(), 6
            ) * 1001
        ) / 1000;
        componentQuantities[1] = PreciseUnitMath.preciseMulCeil(1e18, baseQuantities[1], 18);

        vaultQuantities[0] = componentQuantities[0];

        (bytes memory quotes0, uint256 sellAmount0) =
            getQuoteDataForMint(componentQuantities[0], tokens["usdc"], tokens["weth"]);
        (bytes memory quotes1, uint256 sellAmount1) =
            getQuoteDataForMint(componentQuantities[1], tokens["dai"], tokens["weth"]);
        quotes[0] = quotes0;
        quotes[1] = quotes1;

        uint256 amountWithSlippage = ((sellAmount0 + sellAmount1) * 101 / 100);

        deal(tokens["weth"], alice, amountWithSlippage);

        vm.prank(alice);
        IERC20(tokens["weth"]).approve(address(tradeIssuer), amountWithSlippage);

        vm.prank(alice);
        uint256 totalNativeTokenUsed = tradeIssuer.mintChamberFromToken(
            ITradeIssuer.IssuanceParams(
                quotes,
                IERC20(tokens["weth"]),
                amountWithSlippage,
                1e18,
                IChamber(address(baseChamber)),
                IIssuerWizard(address(issuerWizard)),
                components,
                componentQuantities,
                vaults,
                vaultAssets,
                vaultQuantities,
                5
            )
        );
        assertEq(totalNativeTokenUsed, amountWithSlippage - IERC20(tokens["weth"]).balanceOf(alice));
        assertEq(IERC20(address(baseChamber)).totalSupply(), 1e18);

        // Now redeem

        // Calcualte quantities to sell
        componentQuantities[0] = (
            PreciseUnitMath.preciseMulCeil(
                ERC20(address(baseChamber)).balanceOf(alice), baseQuantities[0], 18
            ).preciseMulCeil(IVault(vaults[0]).pricePerShare(), 6)
        );

        componentQuantities[1] = PreciseUnitMath.preciseMulCeil(
            ERC20(address(baseChamber)).balanceOf(alice), baseQuantities[1], 18
        );

        vaultQuantities[0] = PreciseUnitMath.preciseMulCeil(
            ERC20(address(baseChamber)).balanceOf(alice), baseQuantities[0], 18
        );

        // Ask for quote
        (bytes memory quotes00,) =
            getQuoteDataForRedeem(componentQuantities[0], tokens["usdc"], tokens["weth"]);
        (bytes memory quotes11,) =
            getQuoteDataForRedeem(componentQuantities[1], tokens["dai"], tokens["weth"]);

        quotes[0] = quotes00;
        quotes[1] = quotes11;

        vm.prank(alice);
        ERC20(address(baseChamber)).transfer(address(tradeIssuer), 1e18);

        assertEq(IERC20(address(baseChamber)).balanceOf(alice), 0);
        assertEq(IERC20(address(baseChamber)).balanceOf(address(tradeIssuer)), 1e18);

        // Redeem
        uint256 previousTraderBalance =
            IERC20(address(tokens["weth"])).balanceOf(address(tradeIssuer));
        vm.prank(alice);
        uint256 totalWETHReceived = tradeIssuer.redeemChamber(
            ITradeIssuer.IssuanceParams(
                quotes,
                IERC20(tokens["weth"]),
                0, // Can be any value since it wont be used at redeemChamber
                1e18,
                IChamber(address(baseChamber)),
                IIssuerWizard(address(issuerWizard)),
                components,
                componentQuantities,
                vaults,
                vaultAssets,
                vaultQuantities,
                5
            )
        );

        assertEq(
            IERC20(address(tokens["weth"])).balanceOf(address(tradeIssuer)),
            previousTraderBalance + totalWETHReceived
        );
        assertEq(IERC20(address(baseChamber)).balanceOf(alice), 0);
        assertEq(IERC20(address(baseChamber)).totalSupply(), 0);
        assertEq(IERC20(address(baseConstituents[0])).balanceOf(address(baseChamber)), 0);
        assertEq(IERC20(address(baseConstituents[1])).balanceOf(address(baseChamber)), 0);
    }

    /**
     * [SUCCESS] Can redeem chamber that has ONLY ERC20 assets.
     */
    function testRedeemERC20AssetsOnly() public {
        // Mint some amount to alice
        vaultAssets = new address[](0);
        vaults = new address[](0);
        vaultQuantities = new uint256[](0);

        baseConstituents[0] = tokens["usdc"];
        baseConstituents[1] = tokens["dai"];
        components = baseConstituents;

        baseChamber = chamberFactory.getChamberWithCustomTokens(baseConstituents, baseQuantities);

        componentQuantities[0] = PreciseUnitMath.preciseMulCeil(1e18, baseQuantities[0], 18);
        componentQuantities[1] = PreciseUnitMath.preciseMulCeil(1e18, baseQuantities[1], 18);

        (bytes memory quotes0, uint256 sellAmount0) =
            getQuoteDataForMint(componentQuantities[0], tokens["usdc"], tokens["weth"]);
        (bytes memory quotes1, uint256 sellAmount1) =
            getQuoteDataForMint(componentQuantities[1], tokens["dai"], tokens["weth"]);
        quotes[0] = quotes0;
        quotes[1] = quotes1;

        uint256 amountWithSlippage = ((sellAmount0 + sellAmount1) * 101 / 100);

        deal(tokens["weth"], alice, amountWithSlippage);

        vm.prank(alice);
        IERC20(tokens["weth"]).approve(address(tradeIssuer), amountWithSlippage);

        vm.prank(alice);
        uint256 totalNativeTokenUsed = tradeIssuer.mintChamberFromToken(
            ITradeIssuer.IssuanceParams(
                quotes,
                IERC20(tokens["weth"]),
                amountWithSlippage,
                1e18,
                IChamber(address(baseChamber)),
                IIssuerWizard(address(issuerWizard)),
                components,
                componentQuantities,
                vaults,
                vaultAssets,
                vaultQuantities,
                5
            )
        );
        assertEq(totalNativeTokenUsed, amountWithSlippage - IERC20(tokens["weth"]).balanceOf(alice));
        assertEq(IERC20(address(baseChamber)).totalSupply(), 1e18);

        // Now redeem

        // Calcualte quantities to sell
        componentQuantities[0] = PreciseUnitMath.preciseMulCeil(
            ERC20(address(baseChamber)).balanceOf(alice), baseQuantities[0], 18
        );

        componentQuantities[1] = PreciseUnitMath.preciseMulCeil(
            ERC20(address(baseChamber)).balanceOf(alice), baseQuantities[1], 18
        );

        // Ask for quote
        (bytes memory quotes00,) =
            getQuoteDataForRedeem(componentQuantities[0], tokens["usdc"], tokens["weth"]);
        (bytes memory quotes11,) =
            getQuoteDataForRedeem(componentQuantities[1], tokens["dai"], tokens["weth"]);

        quotes[0] = quotes00;
        quotes[1] = quotes11;

        vm.prank(alice);
        ERC20(address(baseChamber)).transfer(address(tradeIssuer), 1e18);

        assertEq(IERC20(address(baseChamber)).balanceOf(alice), 0);
        assertEq(IERC20(address(baseChamber)).balanceOf(address(tradeIssuer)), 1e18);

        // Redeem
        uint256 previousTraderBalance =
            IERC20(address(tokens["weth"])).balanceOf(address(tradeIssuer));
        vm.prank(alice);
        uint256 totalWETHReceived = tradeIssuer.redeemChamber(
            ITradeIssuer.IssuanceParams(
                quotes,
                IERC20(tokens["weth"]),
                0, // Can be any value since it wont be used at redeemChamber
                1e18,
                IChamber(address(baseChamber)),
                IIssuerWizard(address(issuerWizard)),
                components,
                componentQuantities,
                vaults,
                vaultAssets,
                vaultQuantities,
                5
            )
        );

        assertEq(
            IERC20(address(tokens["weth"])).balanceOf(address(tradeIssuer)),
            previousTraderBalance + totalWETHReceived
        );
        assertEq(IERC20(address(baseChamber)).balanceOf(alice), 0);
        assertEq(IERC20(address(baseChamber)).totalSupply(), 0);
        assertEq(IERC20(address(baseConstituents[0])).balanceOf(address(baseChamber)), 0);
        assertEq(IERC20(address(baseConstituents[1])).balanceOf(address(baseChamber)), 0);
    }

    /**
     * [SUCCESS] Can redeem chamber that has ONLY Vault assets.
     */
    function testRedeemVaultsAssetsOnly() public {
        // Mint some amount to alice
        vaultAssets = new address[](2);
        vaults = new address[](2);
        vaultQuantities = new uint256[](2);

        baseConstituents[0] = tokens["yusdc"];
        baseConstituents[1] = tokens["ydai"];
        components[0] = tokens["usdc"];
        components[1] = tokens["dai"];
        vaultAssets[0] = tokens["usdc"];
        vaultAssets[1] = tokens["dai"];
        vaults[0] = tokens["yusdc"];
        vaults[1] = tokens["ydai"];

        baseChamber = chamberFactory.getChamberWithCustomTokens(baseConstituents, baseQuantities);

        componentQuantities[0] = (
            PreciseUnitMath.preciseMulCeil(1e18, baseQuantities[0], 18).preciseMulCeil(
                IVault(vaults[0]).pricePerShare(), 6
            ) * 1001
        ) / 1000;
        componentQuantities[1] = (
            PreciseUnitMath.preciseMulCeil(1e18, baseQuantities[0], 18).preciseMulCeil(
                IVault(vaults[1]).pricePerShare(), 6
            ) * 1001
        ) / 1000;

        vaultQuantities = componentQuantities;

        (bytes memory quotes0, uint256 sellAmount0) =
            getQuoteDataForMint(componentQuantities[0], tokens["usdc"], tokens["weth"]);
        (bytes memory quotes1, uint256 sellAmount1) =
            getQuoteDataForMint(componentQuantities[1], tokens["dai"], tokens["weth"]);
        quotes[0] = quotes0;
        quotes[1] = quotes1;

        uint256 amountWithSlippage = ((sellAmount0 + sellAmount1) * 101 / 100);

        deal(tokens["weth"], alice, amountWithSlippage);

        vm.prank(alice);
        IERC20(tokens["weth"]).approve(address(tradeIssuer), amountWithSlippage);

        vm.prank(alice);
        uint256 totalNativeTokenUsed = tradeIssuer.mintChamberFromToken(
            ITradeIssuer.IssuanceParams(
                quotes,
                IERC20(tokens["weth"]),
                amountWithSlippage,
                1e18,
                IChamber(address(baseChamber)),
                IIssuerWizard(address(issuerWizard)),
                components,
                componentQuantities,
                vaults,
                vaultAssets,
                vaultQuantities,
                5
            )
        );
        assertEq(totalNativeTokenUsed, amountWithSlippage - IERC20(tokens["weth"]).balanceOf(alice));
        assertEq(IERC20(address(baseChamber)).totalSupply(), 1e18);

        // Now redeem

        // Calcualte quantities to sell
        componentQuantities[0] = (
            PreciseUnitMath.preciseMulCeil(
                ERC20(address(baseChamber)).balanceOf(alice), baseQuantities[0], 18
            ).preciseMulCeil(IVault(vaults[0]).pricePerShare(), 6)
        );

        componentQuantities[1] = PreciseUnitMath.preciseMulCeil(
            ERC20(address(baseChamber)).balanceOf(alice), baseQuantities[0], 18
        ).preciseMulCeil(IVault(vaults[1]).pricePerShare(), 6);

        vaultQuantities[0] = PreciseUnitMath.preciseMulCeil(
            ERC20(address(baseChamber)).balanceOf(alice), baseQuantities[0], 18
        );

        vaultQuantities[1] = PreciseUnitMath.preciseMulCeil(
            ERC20(address(baseChamber)).balanceOf(alice), baseQuantities[1], 18
        );

        // Ask for quote
        (bytes memory quotes00,) =
            getQuoteDataForRedeem(componentQuantities[0], tokens["usdc"], tokens["weth"]);
        (bytes memory quotes11,) =
            getQuoteDataForRedeem(componentQuantities[1], tokens["dai"], tokens["weth"]);

        quotes[0] = quotes00;
        quotes[1] = quotes11;

        vm.prank(alice);
        ERC20(address(baseChamber)).transfer(address(tradeIssuer), 1e18);

        assertEq(IERC20(address(baseChamber)).balanceOf(alice), 0);
        assertEq(IERC20(address(baseChamber)).balanceOf(address(tradeIssuer)), 1e18);

        // Redeem
        uint256 previousTraderBalance =
            IERC20(address(tokens["weth"])).balanceOf(address(tradeIssuer));
        vm.prank(alice);
        uint256 totalWETHReceived = tradeIssuer.redeemChamber(
            ITradeIssuer.IssuanceParams(
                quotes,
                IERC20(tokens["weth"]),
                0, // Can be any value since it wont be used at redeemChamber
                1e18,
                IChamber(address(baseChamber)),
                IIssuerWizard(address(issuerWizard)),
                components,
                componentQuantities,
                vaults,
                vaultAssets,
                vaultQuantities,
                5
            )
        );

        assertEq(
            IERC20(address(tokens["weth"])).balanceOf(address(tradeIssuer)),
            previousTraderBalance + totalWETHReceived
        );
        assertEq(IERC20(address(baseChamber)).balanceOf(alice), 0);
        assertEq(IERC20(address(baseChamber)).totalSupply(), 0);
        assertEq(IERC20(address(baseConstituents[0])).balanceOf(address(baseChamber)), 0);
        assertEq(IERC20(address(baseConstituents[1])).balanceOf(address(baseChamber)), 0);
    }

    /**
     * [SUCCESS] Can redeem chamber with a constituent being the output token.
     */
    function testRedeemWithAConsituentBeingTheOutputToken() public {
        // Mint some amount to alice
        vaultAssets = new address[](1);
        vaults = new address[](1);
        vaultQuantities = new uint256[](1);

        baseConstituents[0] = tokens["yusdc"];
        baseConstituents[1] = tokens["dai"];
        components[0] = tokens["usdc"];
        components[1] = tokens["dai"];
        vaultAssets[0] = tokens["usdc"];
        vaults[0] = tokens["yusdc"];

        baseChamber = chamberFactory.getChamberWithCustomTokens(baseConstituents, baseQuantities);

        componentQuantities[0] = (
            PreciseUnitMath.preciseMulCeil(1e18, baseQuantities[0], 18).preciseMulCeil(
                IVault(vaults[0]).pricePerShare(), 6
            ) * 1001
        ) / 1000;
        componentQuantities[1] = PreciseUnitMath.preciseMulCeil(1e18, baseQuantities[1], 18);

        vaultQuantities[0] = componentQuantities[0];

        (bytes memory quotes0, uint256 sellAmount0) =
            getQuoteDataForMint(componentQuantities[0], tokens["usdc"], tokens["weth"]);
        (bytes memory quotes1, uint256 sellAmount1) =
            getQuoteDataForMint(componentQuantities[1], tokens["dai"], tokens["weth"]);
        quotes[0] = quotes0;
        quotes[1] = quotes1;

        uint256 amountWithSlippage = ((sellAmount0 + sellAmount1) * 101 / 100);

        deal(tokens["weth"], alice, amountWithSlippage);

        vm.prank(alice);
        IERC20(tokens["weth"]).approve(address(tradeIssuer), amountWithSlippage);

        vm.prank(alice);
        uint256 totalNativeTokenUsed = tradeIssuer.mintChamberFromToken(
            ITradeIssuer.IssuanceParams(
                quotes,
                IERC20(tokens["weth"]),
                amountWithSlippage,
                1e18,
                IChamber(address(baseChamber)),
                IIssuerWizard(address(issuerWizard)),
                components,
                componentQuantities,
                vaults,
                vaultAssets,
                vaultQuantities,
                5
            )
        );
        assertEq(totalNativeTokenUsed, amountWithSlippage - IERC20(tokens["weth"]).balanceOf(alice));
        assertEq(IERC20(address(baseChamber)).totalSupply(), 1e18);

        // Now redeem

        // Calcualte quantities to sell
        componentQuantities[0] = (
            PreciseUnitMath.preciseMulCeil(
                ERC20(address(baseChamber)).balanceOf(alice), baseQuantities[0], 18
            ).preciseMulCeil(IVault(vaults[0]).pricePerShare(), 6)
        );

        componentQuantities[1] = PreciseUnitMath.preciseMulCeil(
            ERC20(address(baseChamber)).balanceOf(alice), baseQuantities[1], 18
        );

        vaultQuantities[0] = PreciseUnitMath.preciseMulCeil(
            ERC20(address(baseChamber)).balanceOf(alice), baseQuantities[0], 18
        );

        // Ask for quote
        (bytes memory quotes00,) =
            getQuoteDataForRedeem(componentQuantities[0], tokens["usdc"], tokens["dai"]);

        quotes[0] = quotes00;

        vm.prank(alice);
        ERC20(address(baseChamber)).transfer(address(tradeIssuer), 1e18);

        assertEq(IERC20(address(baseChamber)).balanceOf(alice), 0);
        assertEq(IERC20(address(baseChamber)).balanceOf(address(tradeIssuer)), 1e18);

        // Redeem
        uint256 previousTraderBalance =
            IERC20(address(tokens["dai"])).balanceOf(address(tradeIssuer));
        vm.prank(alice);
        uint256 totalDaiReceived = tradeIssuer.redeemChamber(
            ITradeIssuer.IssuanceParams(
                quotes,
                IERC20(tokens["dai"]),
                0, // Can be any value since it wont be used at redeemChamber
                1e18,
                IChamber(address(baseChamber)),
                IIssuerWizard(address(issuerWizard)),
                components,
                componentQuantities,
                vaults,
                vaultAssets,
                vaultQuantities,
                5
            )
        );
        assertEq(
            IERC20(address(tokens["dai"])).balanceOf(address(tradeIssuer)),
            previousTraderBalance + totalDaiReceived
        );
        assertEq(IERC20(address(baseChamber)).balanceOf(alice), 0);
        assertEq(IERC20(address(baseChamber)).totalSupply(), 0);
        assertEq(IERC20(address(baseConstituents[0])).balanceOf(address(baseChamber)), 0);
        assertEq(IERC20(address(baseConstituents[1])).balanceOf(address(baseChamber)), 0);
    }
}