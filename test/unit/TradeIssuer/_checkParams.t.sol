// Copyright 2022 Smash Works Inc.
// SPDX-License-Identifier: Apache License 2.0
pragma solidity ^0.8.17.0;

import "forge-std/Test.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IChamber } from "chambers/interfaces/IChamber.sol";
import { IIssuerWizard } from "chambers/interfaces/IIssuerWizard.sol";
import { ExposedTradeIssuer } from "test/utils/ExposedTradeIssuer.sol";
import { ITradeIssuer } from "src/interfaces/ITradeIssuer.sol";

contract TradeIssuerUnitInternalCheckParamsTest is Test {
    /*//////////////////////////////////////////////////////////////
                              VARIABLES
    //////////////////////////////////////////////////////////////*/

    ExposedTradeIssuer public tradeIssuer;
    IChamber public chamber;
    IIssuerWizard public issuerWizard;
    address payable public dexAgg = payable(address(0x1));
    address public wETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address public uSDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address public dAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    address public yUSDC = 0xa354F35829Ae975e850e23e9615b11Da1B3dC4DE;
    address public yDAI = 0xdA816459F1AB5631232FE5e97a05BBBb94970c95;
    bytes[] public quotes = new bytes[](2);
    address[] public components = new address[](2);
    uint256[] public componentQuantities = new uint256[](2);
    address[] public vaults = new address[](2);
    address[] public vaultAssets = new address[](2);
    uint256[] public vaultQuantities = new uint256[](2);

    /*//////////////////////////////////////////////////////////////
                              SET UP
    //////////////////////////////////////////////////////////////*/

    function setUp() public {
        tradeIssuer = new ExposedTradeIssuer(dexAgg, wETH);
        vm.label(address(tradeIssuer), "TradeIssuer");
        chamber = IChamber(address(0x2));
        issuerWizard = IIssuerWizard(address(0x3));
        vaults[0] = yUSDC;
        vaults[1] = yDAI;
        vaultAssets[0] = uSDC;
        vaultAssets[1] = dAI;
        quotes[0] = bytes("0x123456");
        quotes[1] = bytes("0x654321");
        components[0] = uSDC;
        components[1] = dAI;
    }

    /*//////////////////////////////////////////////////////////////
                              REVERT
    //////////////////////////////////////////////////////////////*/

    /**
     * [REVERT] Chamber amount must be greater than zero.
     */
    function testCannotMintWithZeroMintAmount(
        uint256 componentQuantities0,
        uint256 componentQuantities1,
        uint256 vaultQuantities0,
        uint256 vaultQuantities1,
        uint256 baseTokenBounds
    ) public {
        uint256 chamberAmount = 0;

        componentQuantities[0] = componentQuantities0;
        componentQuantities[1] = componentQuantities1;
        vaultQuantities[0] = vaultQuantities0;
        vaultQuantities[1] = vaultQuantities1;

        vm.expectRevert(bytes("Chamber amount cannot be zero"));
        tradeIssuer.checkParams(
            ITradeIssuer.IssuanceParams(
                quotes,
                IERC20(wETH),
                baseTokenBounds,
                chamberAmount,
                chamber,
                issuerWizard,
                components,
                componentQuantities,
                vaults,
                vaultAssets,
                vaultQuantities,
                5
            )
        );
    }

    /**
     * [REVERT] Components array cannot be empty
     */
    function testCannotMintWithZeroComponentsArray(uint256 baseTokenBounds, uint64 chamberAmount)
        public
    {
        vm.assume(chamberAmount > 0);
        components = new address[](0);

        vm.expectRevert(bytes("Components array cannot be empty"));
        tradeIssuer.checkParams(
            ITradeIssuer.IssuanceParams(
                quotes,
                IERC20(wETH),
                baseTokenBounds,
                chamberAmount,
                chamber,
                issuerWizard,
                components,
                componentQuantities,
                vaults,
                vaultAssets,
                vaultQuantities,
                5
            )
        );
    }

    /**
     * [REVERT] Components and quotes array lengths must match
     */
    function testCannotMintWithComponentsAndQuotesHavingDifferentArrayLengths(
        uint256 componentQuantities0,
        uint256 componentQuantities1,
        uint256 vaultQuantities0,
        uint256 vaultQuantities1,
        uint256 baseTokenBounds,
        uint64 chamberAmount
    ) public {
        vm.assume(chamberAmount > 0);
        componentQuantities[0] = componentQuantities0;
        componentQuantities[1] = componentQuantities1;
        vaultQuantities[0] = vaultQuantities0;
        vaultQuantities[1] = vaultQuantities1;
        bytes[] memory oneElementQuotes = new bytes[](0);

        vm.expectRevert(bytes("Components and quotes must match"));
        tradeIssuer.checkParams(
            ITradeIssuer.IssuanceParams(
                oneElementQuotes,
                IERC20(wETH),
                baseTokenBounds,
                chamberAmount,
                chamber,
                issuerWizard,
                components,
                componentQuantities,
                vaults,
                vaultAssets,
                vaultQuantities,
                5
            )
        );
    }

    /**
     * [REVERT] Components and components quantities array lengths must match
     */
    function testCannotMintWithComponentsAndComponentsQuantitiesHavingDifferentArrayLengths(
        uint256 vaultQuantities0,
        uint256 vaultQuantities1,
        uint256 baseTokenBounds,
        uint64 chamberAmount
    ) public {
        vm.assume(chamberAmount > 0);
        vaultQuantities[0] = vaultQuantities0;
        vaultQuantities[1] = vaultQuantities1;
        uint256[] memory oneElementComponentQuantities = new uint256[](0);

        vm.expectRevert(bytes("Components and qtys. must match"));
        tradeIssuer.checkParams(
            ITradeIssuer.IssuanceParams(
                quotes,
                IERC20(wETH),
                baseTokenBounds,
                chamberAmount,
                chamber,
                issuerWizard,
                components,
                oneElementComponentQuantities,
                vaults,
                vaultAssets,
                vaultQuantities,
                5
            )
        );
    }

    /**
     * [REVERT] Vaults and vault assets array lengths must match
     */
    function testCannotMintWithVaultsAndVaultAssetsHavingDifferentArrayLengths(
        uint256 componentQuantities0,
        uint256 componentQuantities1,
        uint256 vaultQuantities0,
        uint256 vaultQuantities1,
        uint256 baseTokenBounds,
        uint64 chamberAmount
    ) public {
        vm.assume(chamberAmount > 0);
        componentQuantities[0] = componentQuantities0;
        componentQuantities[1] = componentQuantities1;
        vaultQuantities[0] = vaultQuantities0;
        vaultQuantities[1] = vaultQuantities1;
        address[] memory oneElementVaultAssets = new address[](0);

        vm.expectRevert(bytes("Vaults and Assets must match"));
        tradeIssuer.checkParams(
            ITradeIssuer.IssuanceParams(
                quotes,
                IERC20(wETH),
                baseTokenBounds,
                chamberAmount,
                chamber,
                issuerWizard,
                components,
                componentQuantities,
                vaults,
                oneElementVaultAssets,
                vaultQuantities,
                5
            )
        );
    }

    /**
     * [REVERT] Vaults assets and vault quantities array lengths must match
     */
    function testCannotMintWithVaultAssetsAndVaultQuantitiesHavingDifferentArrayLengths(
        uint256 componentQuantities0,
        uint256 componentQuantities1,
        uint256 baseTokenBounds,
        uint64 chamberAmount
    ) public {
        vm.assume(chamberAmount > 0);
        componentQuantities[0] = componentQuantities0;
        componentQuantities[1] = componentQuantities1;

        uint256[] memory oneElementVaultQuantities = new uint256[](0);

        vm.expectRevert(bytes("Vault and Deposits must match"));
        tradeIssuer.checkParams(
            ITradeIssuer.IssuanceParams(
                quotes,
                IERC20(wETH),
                baseTokenBounds,
                chamberAmount,
                chamber,
                issuerWizard,
                components,
                componentQuantities,
                vaults,
                vaultAssets,
                oneElementVaultQuantities,
                5
            )
        );
    }
    /*//////////////////////////////////////////////////////////////
                              SUCCESS
    //////////////////////////////////////////////////////////////*/

    /**
     * [SUCCESS] Should not revert with correct inputs.
     */
    function testSuccessWithCorrectInputs(
        uint256 componentQuantities0,
        uint256 componentQuantities1,
        uint256 vaultQuantities0,
        uint256 vaultQuantities1,
        uint256 baseTokenBounds,
        uint64 chamberAmount
    ) public {
        vm.assume(chamberAmount > 0);

        componentQuantities[0] = componentQuantities0;
        componentQuantities[1] = componentQuantities1;
        vaultQuantities[0] = vaultQuantities0;
        vaultQuantities[1] = vaultQuantities1;

        tradeIssuer.checkParams(
            ITradeIssuer.IssuanceParams(
                quotes,
                IERC20(wETH),
                baseTokenBounds,
                chamberAmount,
                chamber,
                issuerWizard,
                components,
                componentQuantities,
                vaults,
                vaultAssets,
                vaultQuantities,
                5
            )
        );
    }

    /**
     * [SUCCESS] Should not revert with correct inputs and having
     * all the vault related information empty because a Chamber may not have
     * ERC4626 compliant tokens every time.
     */
    function testSuccessWithCorrectInputsAndEmptyVaultsParams(
        uint256 componentQuantities0,
        uint256 componentQuantities1,
        uint256 baseTokenBounds,
        uint64 chamberAmount
    ) public {
        vm.assume(chamberAmount > 0);

        componentQuantities[0] = componentQuantities0;
        componentQuantities[1] = componentQuantities1;

        uint256[] memory emptyVaultQuantities = new uint256[](0);
        address[] memory emptyVaultAssets = new address[](0);
        address[] memory emptyVaults = new address[](0);

        tradeIssuer.checkParams(
            ITradeIssuer.IssuanceParams(
                quotes,
                IERC20(wETH),
                baseTokenBounds,
                chamberAmount,
                chamber,
                issuerWizard,
                components,
                componentQuantities,
                emptyVaults,
                emptyVaultAssets,
                emptyVaultQuantities,
                5
            )
        );
    }
}
