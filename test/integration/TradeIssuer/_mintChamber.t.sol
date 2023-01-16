// Copyright 2022 Smash Works Inc.
// SPDX-License-Identifier: Apache License 2.0
pragma solidity ^0.8.17.0;

import {ChamberTestUtils} from "test/utils/ChamberTestUtils.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Chamber} from "chambers/Chamber.sol";
import {ChamberFactory} from "test/utils/factories.sol";
import {IssuerWizard} from "chambers/IssuerWizard.sol";
import {ITradeIssuer} from "src/interfaces/ITradeIssuer.sol";
import {IChamber} from "chambers/interfaces/IChamber.sol";
import {IIssuerWizard} from "chambers/interfaces/IIssuerWizard.sol";
import {IVault} from "src/interfaces/IVault.sol";
import {PreciseUnitMath} from "chambers/lib/PreciseUnitMath.sol";
import {ExposedTradeIssuer} from "test/utils/ExposedTradeIssuer.sol";

contract TradeIssuerIntegrationInternalMintChamberTest is ChamberTestUtils {
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
        vm.label(address(tradeIssuer), "TradeIssuer");

        issuerWizard = new IssuerWizard();

        baseConstituents[0] = tokens["yusdc"];
        baseConstituents[1] = tokens["ydai"];
        baseQuantities[0] = 2e6;
        baseQuantities[1] = 2e6;

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
     * [REVERT] Cannot mint if an asset was underbought in a dex swap
     */
    function testCannotMintWithAnUnderboughtAsset() public {
        vaultAssets = new address[](1);
        vaults = new address[](1);
        vaultQuantities = new uint256[](1);

        baseConstituents[0] = tokens["yusdc"];
        baseConstituents[1] = tokens["dai"];
        components[0] = tokens["usdc"];
        components[1] = tokens["dai"];
        vaultAssets[0] = tokens["usdc"];
        vaults[0] = tokens["yusdc"];

        uint256 baseNormal0Quantity = 2e6; // original quantity
        baseQuantities[0] = baseNormal0Quantity * 2; // duplicate so we can mess with the required amounts

        baseChamber = chamberFactory.getChamberWithCustomTokens(baseConstituents, baseQuantities);

        componentQuantities[0] = (
            PreciseUnitMath.preciseMulCeil(1e18, baseNormal0Quantity, 18).preciseMulCeil(
                IVault(vaults[0]).pricePerShare(), 6
            ) * 1001
        ) / 1000;
        componentQuantities[1] = PreciseUnitMath.preciseMulCeil(1e18, baseQuantities[1], 18);

        vaultQuantities[0] = componentQuantities[0];

        (bytes memory quotes0, uint256 sellAmount0) =
            getQuoteDataForMint(baseNormal0Quantity, tokens["usdc"], tokens["weth"]); // smaller buyAmount
        (bytes memory quotes1, uint256 sellAmount1) =
            getQuoteDataForMint(componentQuantities[1], tokens["dai"], tokens["weth"]);
        quotes[0] = quotes0;
        quotes[1] = quotes1;
        deal(tokens["weth"], address(tradeIssuer), ((sellAmount0 + sellAmount1) * 101 / 100));

        vm.expectRevert(bytes("Underbought dex asset"));
        tradeIssuer.mintChamber(
            ITradeIssuer.IssuanceParams(
                quotes,
                IERC20(tokens["weth"]),
                ((sellAmount0 + sellAmount1) * 101 / 100),
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

        assertEq(IERC20(address(baseChamber)).balanceOf(address(tradeIssuer)), 0);
        assertEq(
            IERC20(address(tokens["weth"])).balanceOf(address(tradeIssuer)),
            ((sellAmount0 + sellAmount1) * 101) / 100
        );
        assertEq(IERC20(address(components[0])).balanceOf(address(tradeIssuer)), 0);
        assertEq(IERC20(address(components[1])).balanceOf(address(tradeIssuer)), 0);
        assertEq(IERC20(address(vaults[0])).balanceOf(address(tradeIssuer)), 0);
    }

    /**
     * [REVERT] Cannot mint an asset that was overbought in a dex swap
     */
    function testCannotMintWithOneOverboughtAsset() public {
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
            getQuoteDataForMint(componentQuantities[0] * 2, tokens["usdc"], tokens["weth"]); // big buyAmount
        (bytes memory quotes1, uint256 sellAmount1) =
            getQuoteDataForMint(componentQuantities[1], tokens["dai"], tokens["weth"]);
        quotes[0] = quotes0;
        quotes[1] = quotes1;
        deal(tokens["weth"], address(tradeIssuer), ((sellAmount0 + sellAmount1) * 101 / 100));

        vm.expectRevert(bytes("Overbought dex asset"));
        tradeIssuer.mintChamber(
            ITradeIssuer.IssuanceParams(
                quotes,
                IERC20(tokens["weth"]),
                ((sellAmount0 + sellAmount1) * 101 / 100),
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

        assertEq(IERC20(address(baseChamber)).balanceOf(address(tradeIssuer)), 0);
        assertEq(
            IERC20(address(tokens["weth"])).balanceOf(address(tradeIssuer)),
            ((sellAmount0 + sellAmount1) * 101) / 100
        );
        assertEq(IERC20(address(components[0])).balanceOf(address(tradeIssuer)), 0);
        assertEq(IERC20(address(components[1])).balanceOf(address(tradeIssuer)), 0);
        assertEq(IERC20(address(vaults[0])).balanceOf(address(tradeIssuer)), 0);
    }

    /**
     * [REVERT] Cannot mint an asset with a bad quote present. The message changes depending on the quote,
     * so the execution will be marked as failed instead of cannot. This test is similar to
     * "testMintOnlyERC20AssetsWithFlag", the only thing that changes is the first quote.
     *
     */
    function testFailMintWithAMalformedQuote() public {
        vaultAssets = new address[](0);
        vaults = new address[](0);
        vaultQuantities = new uint256[](0);

        baseConstituents[0] = tokens["dai"];
        baseConstituents[1] = tokens["yfi"];
        components = baseConstituents;

        baseChamber = chamberFactory.getChamberWithCustomTokens(baseConstituents, baseQuantities);

        componentQuantities[0] = PreciseUnitMath.preciseMulCeil(1e18, baseQuantities[0], 18);
        componentQuantities[1] = PreciseUnitMath.preciseMulCeil(1e18, baseQuantities[1], 18);

        (, uint256 sellAmount0) =
            getQuoteDataForMint(componentQuantities[0], tokens["dai"], tokens["weth"]);
        (bytes memory quotes1, uint256 sellAmount1) =
            getQuoteDataForMint(componentQuantities[1], tokens["yfi"], tokens["weth"]);
        quotes[0] = bytes("BAD-DEX-QUOTE");
        quotes[1] = quotes1;
        deal(tokens["weth"], address(tradeIssuer), ((sellAmount0 + sellAmount1) * 101 / 100));

        tradeIssuer.mintChamber(
            ITradeIssuer.IssuanceParams(
                quotes,
                IERC20(tokens["weth"]),
                ((sellAmount0 + sellAmount1) * 101 / 100),
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

        assertEq(IERC20(address(baseChamber)).balanceOf(address(tradeIssuer)), 1e18);
        assertLe(
            IERC20(address(components[0])).balanceOf(address(tradeIssuer)),
            (componentQuantities[0] * 5) / 1000
        );
        assertLe(
            IERC20(address(components[1])).balanceOf(address(tradeIssuer)),
            (componentQuantities[1] * 5) / 1000
        );
    }

    /**
     * [REVERT] Cannot mint if the component quantities are wrong.
     * buy dex in assets may work but when calling issue it will revert.
     * Overbought or underbought vault assets are checked onchain when deposits
     * are made.
     */
    function testCannotMintWithBadComponentQuantitiesUnderBought() public {
        vaultAssets = new address[](1);
        vaults = new address[](1);
        vaultQuantities = new uint256[](1);

        baseConstituents[0] = tokens["yusdc"];
        baseConstituents[1] = tokens["dai"];
        components[0] = tokens["usdc"];
        components[1] = tokens["dai"];
        vaultAssets[0] = tokens["usdc"];
        vaults[0] = tokens["yusdc"];

        uint256 baseNormal1Quantity = 2e6; // original quantity
        baseQuantities[1] = baseNormal1Quantity * 2; // duplicate so we can mess with the required amounts

        baseChamber = chamberFactory.getChamberWithCustomTokens(baseConstituents, baseQuantities);

        componentQuantities[0] = (
            PreciseUnitMath.preciseMulCeil(1e18, baseQuantities[0], 18).preciseMulCeil(
                IVault(vaults[0]).pricePerShare(), 6
            ) * 1001
        ) / 1000;
        componentQuantities[1] = PreciseUnitMath.preciseMulCeil(1e18, baseNormal1Quantity, 18);

        vaultQuantities[0] = componentQuantities[0];

        (bytes memory quotes0, uint256 sellAmount0) =
            getQuoteDataForMint(componentQuantities[0], tokens["usdc"], tokens["weth"]);
        (bytes memory quotes1, uint256 sellAmount1) =
            getQuoteDataForMint(componentQuantities[1], tokens["dai"], tokens["weth"]);
        quotes[0] = quotes0;
        quotes[1] = quotes1;
        deal(tokens["weth"], address(tradeIssuer), ((sellAmount0 + sellAmount1) * 101 / 100));

        vm.expectRevert(bytes("Dai/insufficient-balance"));
        tradeIssuer.mintChamber(
            ITradeIssuer.IssuanceParams(
                quotes,
                IERC20(tokens["weth"]),
                ((sellAmount0 + sellAmount1) * 101 / 100),
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

        assertEq(IERC20(address(baseChamber)).balanceOf(address(tradeIssuer)), 0);
        assertEq(IERC20(address(baseChamber)).balanceOf(address(tradeIssuer)), 0);
        assertEq(
            IERC20(address(tokens["weth"])).balanceOf(address(tradeIssuer)),
            ((sellAmount0 + sellAmount1) * 101) / 100
        );
        assertEq(IERC20(address(components[0])).balanceOf(address(tradeIssuer)), 0);
        assertEq(IERC20(address(components[1])).balanceOf(address(tradeIssuer)), 0);
        assertEq(IERC20(address(vaults[0])).balanceOf(address(tradeIssuer)), 0);
    }

    /**
     * [REVERT] Cannot mint if the vaultsQuantities is zero in one position.
     */
    function testCannotMintWithZeroVaultDepositAmount() public {
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

        vaultQuantities[0] = 0; // deposit amount at zero

        (bytes memory quotes0, uint256 sellAmount0) =
            getQuoteDataForMint(componentQuantities[0], tokens["usdc"], tokens["weth"]);
        (bytes memory quotes1, uint256 sellAmount1) =
            getQuoteDataForMint(componentQuantities[1], tokens["dai"], tokens["weth"]);
        quotes[0] = quotes0;
        quotes[1] = quotes1;
        deal(tokens["weth"], address(tradeIssuer), ((sellAmount0 + sellAmount1) * 101 / 100));

        vm.expectRevert(bytes("Deposit amount cannot be zero"));
        tradeIssuer.mintChamber(
            ITradeIssuer.IssuanceParams(
                quotes,
                IERC20(tokens["weth"]),
                ((sellAmount0 + sellAmount1) * 101 / 100),
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

        assertEq(IERC20(address(baseChamber)).balanceOf(address(tradeIssuer)), 0);
        assertEq(
            IERC20(address(tokens["weth"])).balanceOf(address(tradeIssuer)),
            ((sellAmount0 + sellAmount1) * 101) / 100
        );
        assertEq(IERC20(address(components[0])).balanceOf(address(tradeIssuer)), 0);
        assertEq(IERC20(address(components[1])).balanceOf(address(tradeIssuer)), 0);
        assertEq(IERC20(address(vaults[0])).balanceOf(address(tradeIssuer)), 0);
    }

    /**
     * [REVERT] Cannot mint if the vault constituent is underbought
     */
    function testCannotMintWithUnderboughtVaultConstituent() public {
        vaultAssets = new address[](1);
        vaults = new address[](1);
        vaultQuantities = new uint256[](1);

        baseConstituents[0] = tokens["yusdc"];
        baseConstituents[1] = tokens["dai"];
        components[0] = tokens["usdc"];
        components[1] = tokens["dai"];
        vaultAssets[0] = tokens["usdc"];
        vaults[0] = tokens["yusdc"];

        uint256 baseNormal0Quantity = 2e6;
        baseQuantities[0] = baseNormal0Quantity * 2;

        baseChamber = chamberFactory.getChamberWithCustomTokens(baseConstituents, baseQuantities);

        componentQuantities[0] = (
            PreciseUnitMath.preciseMulCeil(1e18, baseNormal0Quantity, 18).preciseMulCeil(
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
        deal(tokens["weth"], address(tradeIssuer), ((sellAmount0 + sellAmount1) * 101 / 100));

        vm.expectRevert(bytes("Underbought vault constituent"));
        tradeIssuer.mintChamber(
            ITradeIssuer.IssuanceParams(
                quotes,
                IERC20(tokens["weth"]),
                ((sellAmount0 + sellAmount1) * 101 / 100),
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

        assertEq(IERC20(address(baseChamber)).balanceOf(address(tradeIssuer)), 0);
        assertEq(IERC20(address(baseChamber)).balanceOf(address(tradeIssuer)), 0);
        assertEq(
            IERC20(address(tokens["weth"])).balanceOf(address(tradeIssuer)),
            ((sellAmount0 + sellAmount1) * 101) / 100
        );
        assertEq(IERC20(address(components[0])).balanceOf(address(tradeIssuer)), 0);
        assertEq(IERC20(address(components[1])).balanceOf(address(tradeIssuer)), 0);
        assertEq(IERC20(address(vaults[0])).balanceOf(address(tradeIssuer)), 0);
    }

    /**
     * [REVERT] Cannot mint if the input or native token is overspent
     */
    function testCannotMintWithOverSpentToken() public {
        vaultAssets = new address[](0);
        vaults = new address[](0);
        vaultQuantities = new uint256[](0);

        baseConstituents[0] = tokens["dai"];
        baseQuantities[0] = 2e7; // Increase quantity so it doesn't get mixed up with the slippage
        baseConstituents[1] = tokens["yfi"];
        components = baseConstituents;

        baseChamber = chamberFactory.getChamberWithCustomTokens(baseConstituents, baseQuantities);

        componentQuantities[0] = PreciseUnitMath.preciseMulCeil(1e18, baseQuantities[0], 18);
        componentQuantities[1] = PreciseUnitMath.preciseMulCeil(1e18, baseQuantities[1], 18);

        (bytes memory quotes1, uint256 sellAmount1) =
            getQuoteDataForMint(componentQuantities[1], tokens["yfi"], tokens["dai"]);
        quotes[0] = bytes("0x0001");
        quotes[1] = quotes1;

        deal(
            tokens["dai"],
            address(tradeIssuer),
            (componentQuantities[0] + (sellAmount1 * 101) / 100)
        );
        vm.expectRevert(bytes("Overspent input/native token"));
        tradeIssuer.mintChamber(
            ITradeIssuer.IssuanceParams(
                quotes,
                IERC20(tokens["dai"]),
                ((sellAmount1 * 101) / 100), // max input token considers only the amount for mint
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

        assertEq(IERC20(address(baseChamber)).balanceOf(address(tradeIssuer)), 0);
        assertEq(
            IERC20(address(tokens["dai"])).balanceOf(address(tradeIssuer)),
            (componentQuantities[0] + (sellAmount1 * 101) / 100)
        );
    }

    /*//////////////////////////////////////////////////////////////
                              SUCCESS
    //////////////////////////////////////////////////////////////*/

    /**
     * [SUCCESS] Can mint chamber that has both ERC20 and Vault assets
     */
    function testMintVaultAndERC20Assets() public {
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
        deal(tokens["weth"], address(tradeIssuer), ((sellAmount0 + sellAmount1) * 101 / 100));

        tradeIssuer.mintChamber(
            ITradeIssuer.IssuanceParams(
                quotes,
                IERC20(tokens["weth"]),
                ((sellAmount0 + sellAmount1) * 101 / 100),
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

        assertEq(IERC20(address(baseChamber)).balanceOf(address(tradeIssuer)), 1e18);
        assertLe(
            IERC20(address(components[0])).balanceOf(address(tradeIssuer)),
            (componentQuantities[0] * 5) / 1000
        );
        assertLe(
            IERC20(address(components[1])).balanceOf(address(tradeIssuer)),
            (componentQuantities[1] * 5) / 1000
        );
        assertLe(
            IERC20(address(vaults[0])).balanceOf(address(tradeIssuer)),
            (PreciseUnitMath.preciseMulCeil(1e18, baseQuantities[0], 18) * 5) / 1000
        );
    }

    /**
     * [SUCCESS] Can mint chamber that has both ERC20 and Vault assets, with an overbought constituent
     */
    function testMintVaultAndERC20AssetsWithOverBoughtConstituent() public {
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
        /**
         * At the code line below, the component quantities are three times the required to mint.
         * The quotes are made with that data, so the contract will end up having much more component
         * remaining after the mint.
         */
        componentQuantities[1] = PreciseUnitMath.preciseMulCeil(1e18, baseQuantities[1] * 3, 18);

        vaultQuantities[0] = componentQuantities[0];

        (bytes memory quotes0, uint256 sellAmount0) =
            getQuoteDataForMint(componentQuantities[0], tokens["usdc"], tokens["weth"]);
        (bytes memory quotes1, uint256 sellAmount1) =
            getQuoteDataForMint(componentQuantities[1], tokens["dai"], tokens["weth"]);
        quotes[0] = quotes0;
        quotes[1] = quotes1;
        deal(tokens["weth"], address(tradeIssuer), ((sellAmount0 + sellAmount1) * 101 / 100));

        tradeIssuer.mintChamber(
            ITradeIssuer.IssuanceParams(
                quotes,
                IERC20(tokens["weth"]),
                ((sellAmount0 + sellAmount1) * 101 / 100),
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

        assertEq(IERC20(address(baseChamber)).balanceOf(address(tradeIssuer)), 1e18);
        assertLe(
            IERC20(address(components[0])).balanceOf(address(tradeIssuer)),
            (componentQuantities[0] * 5) / 1000
        );
        assertLe(
            IERC20(address(vaults[0])).balanceOf(address(tradeIssuer)),
            (PreciseUnitMath.preciseMulCeil(1e18, baseQuantities[0], 18) * 5) / 1000
        );
    }

    /**
     * [SUCCESS] Can mint chamber tokens without vault assets.
     */
    function testMintOnlyVaultAssets() public {
        components[0] = tokens["usdc"];
        components[1] = tokens["dai"];
        vaults[0] = tokens["yusdc"];
        vaults[1] = tokens["ydai"];
        componentQuantities[0] = (
            PreciseUnitMath.preciseMulCeil(1e18, baseQuantities[0], 18).preciseMulCeil(
                IVault(vaults[0]).pricePerShare(), 6
            ) * 1001
        ) / 1000;
        componentQuantities[1] = (
            PreciseUnitMath.preciseMulCeil(1e18, baseQuantities[1], 18).preciseMulCeil(
                IVault(vaults[1]).pricePerShare(), 18
            ) * 1001
        ) / 1000;

        vaultQuantities = componentQuantities;

        (bytes memory quotes0, uint256 sellAmount0) =
            getQuoteDataForMint(componentQuantities[0], tokens["usdc"], tokens["weth"]);
        (bytes memory quotes1, uint256 sellAmount1) =
            getQuoteDataForMint(componentQuantities[1], tokens["dai"], tokens["weth"]);
        quotes[0] = quotes0;
        quotes[1] = quotes1;
        deal(tokens["weth"], address(tradeIssuer), ((sellAmount0 + sellAmount1) * 101 / 100));

        tradeIssuer.mintChamber(
            ITradeIssuer.IssuanceParams(
                quotes,
                IERC20(tokens["weth"]),
                ((sellAmount0 + sellAmount1) * 101 / 100),
                1e18,
                IChamber(address(baseChamber)),
                IIssuerWizard(address(issuerWizard)),
                components,
                componentQuantities,
                vaults,
                components,
                vaultQuantities,
                5
            )
        );

        assertEq(IERC20(address(baseChamber)).balanceOf(address(tradeIssuer)), 1e18);
        assertLe(
            IERC20(address(components[0])).balanceOf(address(tradeIssuer)),
            (componentQuantities[0] * 5) / 1000
        );
        assertLe(
            IERC20(address(components[1])).balanceOf(address(tradeIssuer)),
            (componentQuantities[1] * 5) / 1000
        );
        assertLe(
            IERC20(address(vaults[0])).balanceOf(address(tradeIssuer)),
            (PreciseUnitMath.preciseMulCeil(1e18, baseQuantities[0], 18) * 5) / 1000
        );
        assertLe(
            IERC20(address(vaults[1])).balanceOf(address(tradeIssuer)),
            (PreciseUnitMath.preciseMulCeil(1e18, baseQuantities[1], 18) * 5) / 1000
        );
    }

    /**
     * [SUCCESS] Can mint chamber token without vault assets, only ERC20.
     */
    function testMintOnlyERC20Assets() public {
        vaultAssets = new address[](0);
        vaults = new address[](0);
        vaultQuantities = new uint256[](0);

        baseConstituents[0] = tokens["dai"];
        baseConstituents[1] = tokens["yfi"];
        components = baseConstituents;

        baseChamber = chamberFactory.getChamberWithCustomTokens(baseConstituents, baseQuantities);

        componentQuantities[0] = PreciseUnitMath.preciseMulCeil(1e18, baseQuantities[0], 18);
        componentQuantities[1] = PreciseUnitMath.preciseMulCeil(1e18, baseQuantities[1], 18);

        (bytes memory quotes0, uint256 sellAmount0) =
            getQuoteDataForMint(componentQuantities[0], tokens["dai"], tokens["weth"]);
        (bytes memory quotes1, uint256 sellAmount1) =
            getQuoteDataForMint(componentQuantities[1], tokens["yfi"], tokens["weth"]);
        quotes[0] = quotes0;
        quotes[1] = quotes1;
        deal(tokens["weth"], address(tradeIssuer), ((sellAmount0 + sellAmount1) * 101 / 100));

        tradeIssuer.mintChamber(
            ITradeIssuer.IssuanceParams(
                quotes,
                IERC20(tokens["weth"]),
                ((sellAmount0 + sellAmount1) * 101 / 100),
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

        assertEq(IERC20(address(baseChamber)).balanceOf(address(tradeIssuer)), 1e18);
        assertLe(
            IERC20(address(components[0])).balanceOf(address(tradeIssuer)),
            (componentQuantities[0] * 5) / 1000
        );
        assertLe(
            IERC20(address(components[1])).balanceOf(address(tradeIssuer)),
            (componentQuantities[1] * 5) / 1000
        );
    }

    /**
     * [SUCCESS] Mint with one of the chambers being the input token.
     */
    function testMintWithInputTokenAsConstituentERC20AndVaultsChamber() public {
        vaultAssets = new address[](0);
        vaults = new address[](0);
        vaultQuantities = new uint256[](0);

        baseConstituents[0] = tokens["dai"];
        baseConstituents[1] = tokens["yfi"];
        components = baseConstituents;

        baseChamber = chamberFactory.getChamberWithCustomTokens(baseConstituents, baseQuantities);

        componentQuantities[0] = PreciseUnitMath.preciseMulCeil(1e18, baseQuantities[0], 18);
        componentQuantities[1] = PreciseUnitMath.preciseMulCeil(1e18, baseQuantities[1], 18);

        (bytes memory quotes1, uint256 sellAmount1) =
            getQuoteDataForMint(componentQuantities[1], tokens["yfi"], tokens["dai"]);
        quotes[0] = bytes("0x0001");
        quotes[1] = quotes1;

        deal(
            tokens["dai"],
            address(tradeIssuer),
            (componentQuantities[0] + (sellAmount1 * 101) / 100)
        );

        tradeIssuer.mintChamber(
            ITradeIssuer.IssuanceParams(
                quotes,
                IERC20(tokens["dai"]),
                (componentQuantities[0] + (sellAmount1 * 101) / 100),
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

        assertEq(IERC20(address(baseChamber)).balanceOf(address(tradeIssuer)), 1e18);
        /**
         * Wont assert for the first component because it's the input token so the remaining
         * token will be transfered back
         */
        assertLe(
            IERC20(address(components[1])).balanceOf(address(tradeIssuer)),
            (componentQuantities[1] * 5) / 1000
        );
    }

    /**
     * [SUCCESS] Can mint if a vault constituent is overbought
     */
    function testCannotMintWithOverboughtVaultConstituent() public {
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
            PreciseUnitMath.preciseMulCeil(1e18, baseQuantities[0] * 2, 18).preciseMulCeil(
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
        deal(tokens["weth"], address(tradeIssuer), ((sellAmount0 + sellAmount1) * 101 / 100));

        tradeIssuer.mintChamber(
            ITradeIssuer.IssuanceParams(
                quotes,
                IERC20(tokens["weth"]),
                ((sellAmount0 + sellAmount1) * 101 / 100),
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

        assertEq(IERC20(address(baseChamber)).balanceOf(address(tradeIssuer)), 1e18);
        assertLe(
            IERC20(address(components[0])).balanceOf(address(tradeIssuer)),
            (componentQuantities[0] * 5) / 1000
        );
        assertLe(
            IERC20(address(components[1])).balanceOf(address(tradeIssuer)),
            (componentQuantities[1] * 5) / 1000
        );
    }
}
