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
import {PreciseUnitMath} from "chambers/lib/PreciseUnitMath.sol";
import {ExposedTradeIssuer} from "test/utils/ExposedTradeIssuer.sol";

contract TradeIssuerIntegrationInternalWithdrawConstituentsFromVaultsTest is ChamberTestUtils {
    using PreciseUnitMath for uint256;
    using PreciseUnitMath for uint64;

    /*//////////////////////////////////////////////////////////////
                              VARIABLES
    //////////////////////////////////////////////////////////////*/

    ExposedTradeIssuer public tradeIssuer;
    ChamberGod public chamberGod;
    Chamber public baseChamber;
    IssuerWizard public issuerWizard;
    mapping(string => address) public tokens;
    address payable public dexAgg = payable(address(0xDef1C0ded9bec7F1a1670819833240f027b25EfF));
    address public tradeIssuerAddress;
    uint256[] public componentQuantities = new uint256[] (2);
    uint256[] public vaultQuantities = new uint256[](2);
    uint256[] public baseQuantities = new uint256[] (2);
    address[] public components = new address[] (2);
    address[] public baseConstituents = new address[](2);
    address[] public vaults = new address[](2);
    address[] public vaultAssets = new address[](2);
    bytes[] public quotes = new bytes[](2);
    address[] public wizards = new address[](1);
    address[] public managers = new address[](0);

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

        vaults[0] = tokens["yusdc"];
        vaults[1] = tokens["ydai"];
        vaultAssets[0] = tokens["usdc"];
        vaultAssets[1] = tokens["dai"];

        chamberGod = new ChamberGod();
        issuerWizard = new IssuerWizard(address(chamberGod));
        chamberGod.addWizard(address(issuerWizard));

        baseConstituents[0] = tokens["yusdc"];
        baseConstituents[1] = tokens["ydai"];
        baseQuantities[0] = 2e6;
        baseQuantities[1] = 2e6;

        wizards[0] = address(issuerWizard);

        baseChamber = Chamber(
            chamberGod.createChamber(
                "name", "symbol", baseConstituents, baseQuantities, wizards, managers
            )
        );

        vm.label(vm.addr(0x791782394), "ChamberGod");
        vm.label(address(issuerWizard), "IssuerWizard");
        vm.label(address(chamberGod), "ChamberGod");
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
     * [REVERT] Should revert when the expected amount to receive from a withdraw
     * is zero.
     */
    function testsCannotWithdrawConstituentsInVaultWithZeroVaultQuantity(
        uint64 amount,
        uint64 constituentQuantity0,
        uint64 constituentQuantity1
    ) public {
        // Deposit some first
        vm.assume(amount > 1 ether);
        vm.assume(constituentQuantity0 > 10 ** 4); // 0.01 USDC
        vm.assume(constituentQuantity0 < 1000 * (10 ** 6)); // 1000 USDC
        vm.assume(constituentQuantity1 > 10 ** 16); // 0.01 DAI
        vm.assume(constituentQuantity1 < 1000 * (10 ** 18)); // 1000 USDC

        baseQuantities[0] = constituentQuantity0;
        baseQuantities[1] = constituentQuantity1;
        Chamber chamber = Chamber(
            chamberGod.createChamber("name", "symbol", vaults, baseQuantities, wizards, managers)
        );
        uint256 pricePerShare0 = IVault(vaults[0]).pricePerShare();
        uint256 pricePerShare1 = IVault(vaults[1]).pricePerShare();
        uint256 depositAmount0 =
            amount.preciseMulCeil(baseQuantities[0], 18).preciseMulCeil(pricePerShare0, 6);

        uint256 depositAmount1 =
            amount.preciseMulCeil(baseQuantities[1], 18).preciseMulCeil(pricePerShare1, 18);

        vaultQuantities[0] = (depositAmount0 * 100001) / 100000;
        vaultQuantities[1] = (depositAmount1 * 100001) / 100000;

        deal(vaultAssets[0], tradeIssuerAddress, vaultQuantities[0]);
        deal(vaultAssets[1], tradeIssuerAddress, vaultQuantities[1]);

        tradeIssuer.depositConstituentsInVault(
            vaults, vaultAssets, vaultQuantities, IChamber(address(chamber)), amount
        );

        vaultQuantities[0] = 0;
        vaultQuantities[1] = depositAmount1 - 1;
        vm.expectRevert("Withdraw amount cannot be zero");
        tradeIssuer.withdrawConstituentsFromVault(
            vaults, vaultAssets, vaultQuantities, IChamber(address(chamber)), amount
        );

        assertGe(
            IERC20(vaults[0]).balanceOf(tradeIssuerAddress),
            amount.preciseMulCeil(baseQuantities[0], 18)
        );
        assertGe(
            IERC20(vaults[1]).balanceOf(tradeIssuerAddress),
            amount.preciseMulCeil(baseQuantities[0], 18)
        );
        assertGe(IERC20(vaultAssets[0]).balanceOf(tradeIssuerAddress), 0);
        assertGe(IERC20(vaultAssets[1]).balanceOf(tradeIssuerAddress), 0);
    }

    /**
     * [REVERT] Should Revert because trade issuer has no balance of any yToken.
     */
    function testsCannotWithdrawConstituentsInVaultWithZeroBalance(
        uint64 amount,
        uint64 constituentQuantity0,
        uint64 constituentQuantity1
    ) public {
        // Deposit some first
        vm.assume(amount > 1 ether);
        vm.assume(constituentQuantity0 > 10 ** 4); // 0.01 USDC
        vm.assume(constituentQuantity0 < 1000 * (10 ** 6)); // 1000 USDC
        vm.assume(constituentQuantity1 > 10 ** 16); // 0.01 DAI
        vm.assume(constituentQuantity1 < 1000 * (10 ** 18)); // 1000 USDC

        baseQuantities[0] = constituentQuantity0;
        baseQuantities[1] = constituentQuantity1;
        Chamber chamber = Chamber(
            chamberGod.createChamber("name", "symbol", vaults, baseQuantities, wizards, managers)
        );
        vaultQuantities[0] = 1;
        vaultQuantities[1] = 1;
        vm.expectRevert(); //Generic "EvmError: Revert"
        tradeIssuer.withdrawConstituentsFromVault(
            vaults, vaultAssets, vaultQuantities, IChamber(address(chamber)), amount
        );

        assertGe(IERC20(vaults[0]).balanceOf(tradeIssuerAddress), 0);
        assertGe(IERC20(vaults[1]).balanceOf(tradeIssuerAddress), 0);
        assertGe(IERC20(vaultAssets[0]).balanceOf(tradeIssuerAddress), 0);
        assertGe(IERC20(vaultAssets[1]).balanceOf(tradeIssuerAddress), 0);
    }

    /**
     * [REVERT] Should Revert because trade issuer has not enough balance of a yToken.
     * When trying to withdraw a bigger amount
     */
    function testsCannotWithdrawConstituentsInVaultWithNotEnoughBalance(
        uint64 amount,
        uint64 constituentQuantity0,
        uint64 constituentQuantity1
    ) public {
        // Deposit some first
        vm.assume(amount > 1 ether);
        vm.assume(constituentQuantity0 > 10 ** 4); // 0.01 USDC
        vm.assume(constituentQuantity0 < 1000 * (10 ** 6)); // 1000 USDC
        vm.assume(constituentQuantity1 > 10 ** 16); // 0.01 DAI
        vm.assume(constituentQuantity1 < 1000 * (10 ** 18)); // 1000 USDC

        baseQuantities[0] = constituentQuantity0;
        baseQuantities[1] = constituentQuantity1;
        Chamber chamber = Chamber(
            chamberGod.createChamber("name", "symbol", vaults, baseQuantities, wizards, managers)
        );
        uint256 pricePerShare0 = IVault(vaults[0]).pricePerShare();
        uint256 pricePerShare1 = IVault(vaults[1]).pricePerShare();
        uint256 depositAmount0 =
            amount.preciseMulCeil(baseQuantities[0], 18).preciseMulCeil(pricePerShare0, 6);

        uint256 depositAmount1 =
            amount.preciseMulCeil(baseQuantities[1], 18).preciseMulCeil(pricePerShare1, 18);

        vaultQuantities[0] = (depositAmount0 * 100001) / 100000;
        vaultQuantities[1] = (depositAmount1 * 100001) / 100000;

        deal(vaultAssets[0], tradeIssuerAddress, vaultQuantities[0]);
        deal(vaultAssets[1], tradeIssuerAddress, vaultQuantities[1]);

        tradeIssuer.depositConstituentsInVault(
            vaults, vaultAssets, vaultQuantities, IChamber(address(chamber)), amount
        );

        vaultQuantities[0] = depositAmount0 - 1;
        vaultQuantities[1] = depositAmount1 - 1;
        vm.expectRevert(); //Generic "EvmError: Revert"
        tradeIssuer.withdrawConstituentsFromVault(
            vaults,
            vaultAssets,
            vaultQuantities,
            IChamber(address(chamber)),
            amount * 2 // will try to withdraw twice the amount of vault assets
        );

        assertGe(
            IERC20(vaults[0]).balanceOf(tradeIssuerAddress),
            amount.preciseMulCeil(baseQuantities[0], 18)
        );
        assertGe(
            IERC20(vaults[1]).balanceOf(tradeIssuerAddress),
            amount.preciseMulCeil(baseQuantities[0], 18)
        );
        assertGe(IERC20(vaultAssets[0]).balanceOf(tradeIssuerAddress), 0);
        assertGe(IERC20(vaultAssets[1]).balanceOf(tradeIssuerAddress), 0);
    }

    /**
     * [REVERT] Should revert because vault address is not in the mapping of constituents whent trying
     * to get the required withdraw quantities.
     */
    function testsCannotWithdrawInvalidVault(
        uint64 amount,
        uint64 constituentQuantity0,
        uint64 constituentQuantity1
    ) public {
        // Deposit some first
        vm.assume(amount > 1 ether);
        vm.assume(constituentQuantity0 > 10 ** 4); // 0.01 USDC
        vm.assume(constituentQuantity0 < 1000 * (10 ** 6)); // 1000 USDC
        vm.assume(constituentQuantity1 > 10 ** 16); // 0.01 DAI
        vm.assume(constituentQuantity1 < 1000 * (10 ** 18)); // 1000 USDC

        baseQuantities[0] = constituentQuantity0;
        baseQuantities[1] = constituentQuantity1;
        Chamber chamber = Chamber(
            chamberGod.createChamber("name", "symbol", vaults, baseQuantities, wizards, managers)
        );
        uint256 pricePerShare0 = IVault(vaults[0]).pricePerShare();
        uint256 pricePerShare1 = IVault(vaults[1]).pricePerShare();
        uint256 depositAmount0 =
            amount.preciseMulCeil(baseQuantities[0], 18).preciseMulCeil(pricePerShare0, 6);

        uint256 depositAmount1 =
            amount.preciseMulCeil(baseQuantities[1], 18).preciseMulCeil(pricePerShare1, 18);

        vaultQuantities[0] = (depositAmount0 * 100001) / 100000;
        vaultQuantities[1] = (depositAmount1 * 100001) / 100000;

        deal(vaultAssets[0], tradeIssuerAddress, vaultQuantities[0]);
        deal(vaultAssets[1], tradeIssuerAddress, vaultQuantities[1]);

        tradeIssuer.depositConstituentsInVault(
            vaults, vaultAssets, vaultQuantities, IChamber(address(chamber)), amount
        );

        vaultQuantities[0] = depositAmount0 - 1;
        vaultQuantities[1] = depositAmount1 - 1;
        // Change vault address for an invalid one
        vaults[0] = tokens["yfi"];
        vm.expectRevert("Quantity is zero");
        tradeIssuer.withdrawConstituentsFromVault(
            vaults, vaultAssets, vaultQuantities, IChamber(address(chamber)), amount
        );
        // The original vault address that's constituent of the chamber
        assertGe(
            IERC20(tokens["yusdc"]).balanceOf(tradeIssuerAddress),
            amount.preciseMulCeil(baseQuantities[0], 18)
        );
        assertGe(
            IERC20(vaults[1]).balanceOf(tradeIssuerAddress),
            amount.preciseMulCeil(baseQuantities[0], 18)
        );
        assertGe(IERC20(vaultAssets[0]).balanceOf(tradeIssuerAddress), 0);
        assertGe(IERC20(vaultAssets[1]).balanceOf(tradeIssuerAddress), 0);
    }

    /*//////////////////////////////////////////////////////////////
                              SUCCESS
    //////////////////////////////////////////////////////////////*/

    /**
     * [SUCCESS] Should skip everything with empty arrays
     */
    function testsWithdrawConstituentsInVaultWithEmptyArrays(uint256 redeemAmount) public {
        address[] memory emptyVaults = new address[](0);
        address[] memory emptyVaultUnderlyingAssets = new address[](0);
        uint256[] memory emptyVaultQuantities = new uint256[](0);

        tradeIssuer.withdrawConstituentsFromVault(
            emptyVaults,
            emptyVaultUnderlyingAssets,
            emptyVaultQuantities,
            IChamber(address(baseChamber)),
            redeemAmount
        );
    }

    /**
     * [SUCCESS] Should withdraw all assets, andn swap yTokens for underlying assets
     */
    function testsWithdrawConstituentsInVault(
        uint64 amount,
        uint64 constituentQuantity0,
        uint64 constituentQuantity1
    ) public {
        // Deposit some first
        vm.assume(amount > 1 ether);
        vm.assume(constituentQuantity0 > 10 ** 4); // 0.01 USDC
        vm.assume(constituentQuantity0 < 1000 * (10 ** 6)); // 1000 USDC
        vm.assume(constituentQuantity1 > 10 ** 16); // 0.01 DAI
        vm.assume(constituentQuantity1 < 1000 * (10 ** 18)); // 1000 USDC

        baseQuantities[0] = constituentQuantity0;
        baseQuantities[1] = constituentQuantity1;
        Chamber chamber = Chamber(
            chamberGod.createChamber("name", "symbol", vaults, baseQuantities, wizards, managers)
        );
        uint256 pricePerShare0 = IVault(vaults[0]).pricePerShare();
        uint256 pricePerShare1 = IVault(vaults[1]).pricePerShare();
        uint256 depositAmount0 =
            amount.preciseMulCeil(baseQuantities[0], 18).preciseMulCeil(pricePerShare0, 6);

        uint256 depositAmount1 =
            amount.preciseMulCeil(baseQuantities[1], 18).preciseMulCeil(pricePerShare1, 18);

        vaultQuantities[0] = (depositAmount0 * 100001) / 100000;
        vaultQuantities[1] = (depositAmount1 * 100001) / 100000;

        deal(vaultAssets[0], tradeIssuerAddress, vaultQuantities[0]);
        deal(vaultAssets[1], tradeIssuerAddress, vaultQuantities[1]);

        tradeIssuer.depositConstituentsInVault(
            vaults, vaultAssets, vaultQuantities, IChamber(address(chamber)), amount
        );

        vaultQuantities[0] = depositAmount0 - 1;
        vaultQuantities[1] = depositAmount1 - 1;
        tradeIssuer.withdrawConstituentsFromVault(
            vaults, vaultAssets, vaultQuantities, IChamber(address(chamber)), amount
        );

        assertLe(IERC20(vaults[0]).balanceOf(tradeIssuerAddress), (depositAmount0 * 1) / 100000);
        assertLe(IERC20(vaults[1]).balanceOf(tradeIssuerAddress), (depositAmount1 * 1) / 100000);
        assertGe(IERC20(vaultAssets[0]).balanceOf(tradeIssuerAddress), vaultQuantities[0]);
        assertGe(IERC20(vaultAssets[1]).balanceOf(tradeIssuerAddress), vaultQuantities[1]);
    }
}
