// Copyright 2022 Smash Works Inc.
// SPDX-License-Identifier: Apache License 2.0
pragma solidity ^0.8.17.0;

import {ChamberTestUtils} from "test/utils/ChamberTestUtils.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Chamber} from "chambers/Chamber.sol";
import {ChamberGod} from "chambers/ChamberGod.sol";
import {IssuerWizard} from "chambers/IssuerWizard.sol";
import {IVault} from "src/interfaces/IVault.sol";
import {IChamber} from "chambers/interfaces/IChamber.sol";
import {IIssuerWizard} from "chambers/interfaces/IIssuerWizard.sol";
import {PreciseUnitMath} from "chambers/lib/PreciseUnitMath.sol";
import {TradeIssuer} from "src/TradeIssuer.sol";
import {ITradeIssuer} from "src/interfaces/ITradeIssuer.sol";

contract TradeIssuerIntegrationlMintChamberFromTokenTest is ChamberTestUtils {
    using PreciseUnitMath for uint256;
    using PreciseUnitMath for uint64;

    /*//////////////////////////////////////////////////////////////
                              VARIABLES
    //////////////////////////////////////////////////////////////*/

    TradeIssuer public tradeIssuer;
    ChamberGod public chamberGod;
    Chamber public baseChamber;
    IssuerWizard public issuerWizard;
    mapping(string => address) public tokens;
    address payable public alice = payable(address(0x123456));
    address payable public dexAgg = payable(address(0xDef1C0ded9bec7F1a1670819833240f027b25EfF));
    uint256[] public componentQuantities = new uint256[] (3);
    uint256[] public vaultQuantities = new uint256[](3);
    uint256[] public baseQuantities = new uint256[] (3);
    address[] public components = new address[] (3);
    address[] public baseConstituents = new address[](3);
    address[] public vaults = new address[](3);
    address[] public vaultAssets = new address[](3);
    bytes[] public quotes = new bytes[](3);

    /*//////////////////////////////////////////////////////////////
                              SET UP
    //////////////////////////////////////////////////////////////*/

    function setUp() public {
        tokens["weth"] = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
        tokens["usdc"] = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
        tokens["usdt"] = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
        tokens["dai"] = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
        tokens["yusdc"] = 0xa354F35829Ae975e850e23e9615b11Da1B3dC4DE;
        tokens["ydai"] = 0xdA816459F1AB5631232FE5e97a05BBBb94970c95;
        tokens["yfi"] = 0x0bc529c00C6401aEF6D220BE8C6Ea1667F6Ad93e;
        tokens["yusdt"] = 0x3B27F92C0e212C671EA351827EDF93DB27cc0c65;

        tradeIssuer = new TradeIssuer(payable(dexAgg), tokens["weth"]);
        vm.label(address(tradeIssuer), "TradeIssuer");

        baseConstituents[0] = tokens["yusdc"];
        baseConstituents[1] = tokens["ydai"];
        baseConstituents[2] = tokens["yusdt"];
        baseQuantities[0] = 2e6;
        baseQuantities[1] = 2e6;
        baseQuantities[2] = 2e6;
        vaultAssets[0] = tokens["usdc"];
        vaultAssets[1] = tokens["dai"];
        vaultAssets[2] = tokens["usdt"];
        vaults[0] = tokens["yusdc"];
        vaults[1] = tokens["ydai"];
        vaults[2] = tokens["yusdt"];
        components = vaultAssets;
        address[] memory wizards = new address[](1);
        address[] memory managers = new address[](0);

        chamberGod = new ChamberGod();
        issuerWizard = new IssuerWizard(address(chamberGod));
        wizards[0] = address(issuerWizard);
        chamberGod.addWizard(address(issuerWizard));

        baseChamber = Chamber(
            chamberGod.createChamber(
                "name", "symbol", baseConstituents, baseQuantities, wizards, managers
            )
        );

        vm.label(address(chamberGod), "ChamberGod");
        vm.label(address(issuerWizard), "IssuerWizard");
        vm.label(alice, "Alice");
        vm.label(dexAgg, "ZeroEx");
        vm.label(tokens["weth"], "WETH");
        vm.label(tokens["usdc"], "USDC");
        vm.label(tokens["dai"], "DAI");
        vm.label(tokens["usdt"], "USDT");
        vm.label(tokens["yusdc"], "yUSDC");
        vm.label(tokens["ydai"], "yDAI");
        vm.label(tokens["yusdt"], "yUSDT");
        vm.label(tokens["yfi"], "YFI");
    }

    /*//////////////////////////////////////////////////////////////
                              SUCCESS
    //////////////////////////////////////////////////////////////*/

    /**
     * [SUCCESS] Can mint chamber that has both ERC20 and Vault assets
     */
    function testMintVaultAndERC20Assets() public {
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

        componentQuantities[2] = (
            PreciseUnitMath.preciseMulCeil(1e18, baseQuantities[2], 18).preciseMulCeil(
                IVault(vaults[2]).pricePerShare(), 6
            ) * 1001
        ) / 1000;

        vaultQuantities = componentQuantities;

        (bytes memory quotes0, uint256 sellAmount0) =
            getQuoteDataForMint(componentQuantities[0], tokens["usdc"], tokens["weth"]);
        (bytes memory quotes1, uint256 sellAmount1) =
            getQuoteDataForMint(componentQuantities[1], tokens["dai"], tokens["weth"]);
        (bytes memory quotes2, uint256 sellAmount2) =
            getQuoteDataForMint(componentQuantities[2], tokens["usdt"], tokens["weth"]);
        quotes[0] = quotes0;
        quotes[1] = quotes1;
        quotes[2] = quotes2;

        uint256 amountWithSlippage = ((sellAmount0 + sellAmount1 + sellAmount2) * 101 / 100);

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

        assertEq(IERC20(address(baseChamber)).balanceOf(alice), 1e18);
        assertEq(IERC20(address(baseChamber)).balanceOf(address(tradeIssuer)), 0);
        assertEq(IERC20(tokens["weth"]).balanceOf(alice), amountWithSlippage - totalNativeTokenUsed);
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
}
