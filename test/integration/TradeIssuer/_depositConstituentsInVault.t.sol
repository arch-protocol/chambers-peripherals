// Copyright 2022 Smash Works Inc.
// SPDX-License-Identifier: Apache License 2.0
pragma solidity ^0.8.17.0;

import "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IVault} from "src/interfaces/IVault.sol";
import {IChamber} from "chambers/interfaces/IChamber.sol";
import {PreciseUnitMath} from "chambers/lib/PreciseUnitMath.sol";
import {ExposedTradeIssuer} from "test/utils/ExposedTradeIssuer.sol";
import {Chamber} from "chambers/Chamber.sol";
import {ChamberFactory} from "test/utils/factories.sol";

contract TradeIssuerIntegrationInternalDepositAssetsInVaultsTest is Test {
    using PreciseUnitMath for uint256;
    using PreciseUnitMath for uint64;

    /*//////////////////////////////////////////////////////////////
                              VARIABLES
    //////////////////////////////////////////////////////////////*/
    ExposedTradeIssuer public tradeIssuer;
    ChamberFactory public chamberFactory;
    Chamber public chamber;
    address public tradeIssuerAddress;
    address payable public dexAgg = payable(address(0x1));
    address public chamberAddress = (address(chamber));
    address public wETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address public uSDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address public dAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    address public yUSDC = 0xa354F35829Ae975e850e23e9615b11Da1B3dC4DE;
    address public yDAI = 0xdA816459F1AB5631232FE5e97a05BBBb94970c95;
    address[] public vaults = new address[](2);
    address[] public vaultAssets = new address[](2);
    uint256[] public vaultQuantities = new uint256[](2);
    uint256[] public chamberQuantities = new uint256[](2);

    /*//////////////////////////////////////////////////////////////
                              SET UP
    //////////////////////////////////////////////////////////////*/

    function setUp() public {
        tradeIssuer = new ExposedTradeIssuer(dexAgg, wETH);
        tradeIssuerAddress = address(tradeIssuer);
        vm.label(tradeIssuerAddress, "TradeIssuer");
        vaults[0] = yUSDC;
        vaults[1] = yDAI;
        vaultAssets[0] = uSDC;
        vaultAssets[1] = dAI;

        address[] memory wizards = new address[](0);
        address[] memory managers = new address[](0);

        chamberFactory = new ChamberFactory(
          address(this),
          "name",
          "symbol",
          wizards,
          managers
        );
    }

    /*//////////////////////////////////////////////////////////////
                              REVERT
    //////////////////////////////////////////////////////////////*/
    /**
     * [REVERT] Should Revert because trade issuer has no balance of any vaultAssets
     */
    function testCannotDepositWithoutVaultAssetsBalance(
        uint64 mintAmount,
        uint64 constituentQuantity0,
        uint64 constituentQuantity1
    ) public {
        vm.assume(mintAmount > 0);
        vm.assume(constituentQuantity0 > 10 ** 4); // 0.01 USDC
        vm.assume(constituentQuantity0 < 1000 * (10 ** 6)); // 1000 USDC
        vm.assume(constituentQuantity1 > 10 ** 16); // 0.01 DAI
        vm.assume(constituentQuantity1 < 1000 * (10 ** 18)); // 1000 USDC

        uint256 constituent0BalanceBefore = IERC20(vaults[0]).balanceOf(tradeIssuerAddress);
        uint256 constituent1BalanceBefore = IERC20(vaults[1]).balanceOf(tradeIssuerAddress);

        chamberQuantities[0] = constituentQuantity0;
        chamberQuantities[1] = constituentQuantity1;
        chamber = chamberFactory.getChamberWithCustomTokens(vaults, chamberQuantities);
        chamberAddress = address(chamber);

        uint256 pricePerShare0 = IVault(vaults[0]).pricePerShare();
        uint256 pricePerShare1 = IVault(vaults[1]).pricePerShare();
        uint256 depositAmount0 =
            mintAmount.preciseMulCeil(chamberQuantities[0], 18).preciseMulCeil(pricePerShare0, 6);

        uint256 depositAmount1 =
            mintAmount.preciseMulCeil(chamberQuantities[1], 18).preciseMulCeil(pricePerShare1, 18);

        vaultQuantities[0] = (depositAmount0 * 100001) / 100000;
        vaultQuantities[1] = (depositAmount1 * 100001) / 100000;

        // Deposit should happen here

        vm.expectRevert(); // Error message may change over different ERC20 implementations.

        tradeIssuer.depositConstituentsInVault(
            vaults, vaultAssets, vaultQuantities, IChamber(chamberAddress), mintAmount
        );

        uint256 constituent0BalanceAfter = IERC20(vaults[0]).balanceOf(tradeIssuerAddress);
        uint256 constituent1BalanceAfter = IERC20(vaults[1]).balanceOf(tradeIssuerAddress);

        assertEq(IERC20(vaultAssets[0]).balanceOf(tradeIssuerAddress), 0);
        assertEq(IERC20(vaultAssets[1]).balanceOf(tradeIssuerAddress), 0);
        assertGe(constituent0BalanceAfter - constituent0BalanceBefore, 0);
        assertGe(constituent1BalanceAfter - constituent1BalanceBefore, 0);
    }

    /**
     * [REVERT] Balance greater than zero but not enough.
     */
    function testCannotDepositWithUnderboughtAsset(
        uint64 mintAmount,
        uint64 constituentQuantity0,
        uint64 constituentQuantity1
    ) public {
        vm.assume(mintAmount > 10 ** 10); // 0,00000001 Chamber token
        vm.assume(constituentQuantity0 > 10 ** 4); // 0.01 USDC
        vm.assume(constituentQuantity0 < 1000 * (10 ** 6)); // 1000 USDC
        vm.assume(constituentQuantity1 > 10 ** 16); // 0.01 DAI
        vm.assume(constituentQuantity1 < 1000 * (10 ** 18)); // 1000 USDC

        uint256 constituent0BalanceBefore = IERC20(vaults[0]).balanceOf(tradeIssuerAddress);
        uint256 constituent1BalanceBefore = IERC20(vaults[1]).balanceOf(tradeIssuerAddress);

        chamberQuantities[0] = constituentQuantity0 * 1e6;
        chamberQuantities[1] = constituentQuantity1;

        chamber = chamberFactory.getChamberWithCustomTokens(vaults, chamberQuantities);
        chamberAddress = address(chamber);

        uint256 pricePerShare1 = IVault(vaults[1]).pricePerShare();
        uint256 pricePerShare0 = IVault(vaults[0]).pricePerShare();
        uint256 depositAmount0 =
            mintAmount.preciseMulCeil(constituentQuantity0, 18).preciseMulCeil((pricePerShare0), 6);
        uint256 depositAmount1 =
            mintAmount.preciseMulCeil(chamberQuantities[1], 18).preciseMulCeil(pricePerShare1, 18);

        vaultQuantities[0] = (depositAmount0 * 100001) / 100000;
        vaultQuantities[1] = (depositAmount1 * 100001) / 100000;

        deal(vaultAssets[0], tradeIssuerAddress, vaultQuantities[0]);
        deal(vaultAssets[1], tradeIssuerAddress, vaultQuantities[1]);

        vm.expectRevert(bytes("Underbought vault constituent"));

        tradeIssuer.depositConstituentsInVault(
            vaults, vaultAssets, vaultQuantities, IChamber(chamberAddress), mintAmount
        );

        uint256 constituent0BalanceAfter = IERC20(vaults[0]).balanceOf(tradeIssuerAddress);
        uint256 constituent1BalanceAfter = IERC20(vaults[1]).balanceOf(tradeIssuerAddress);

        assertEq(IERC20(vaultAssets[0]).balanceOf(tradeIssuerAddress), vaultQuantities[0]);
        assertEq(IERC20(vaultAssets[1]).balanceOf(tradeIssuerAddress), vaultQuantities[1]);
        assertGe(constituent0BalanceAfter - constituent0BalanceBefore, 0);
        assertGe(constituent1BalanceAfter - constituent1BalanceBefore, 0);
    }

    /**
     * [REVERT] Should revert because depositQuantities has zero amount in
     * the second vault
     */
    function testCannotDepositWithZeroDepositQuantityInSecondAsset(
        uint64 mintAmount,
        uint64 constituentQuantity0,
        uint64 constituentQuantity1
    ) public {
        vm.assume(mintAmount > 0);
        vm.assume(constituentQuantity0 > 10 ** 4); // 0.01 USDC
        vm.assume(constituentQuantity0 < 1000 * (10 ** 6)); // 1000 USDC
        vm.assume(constituentQuantity1 > 10 ** 16); // 0.01 DAI
        vm.assume(constituentQuantity1 < 1000 * (10 ** 18)); // 1000 USDC

        uint256 constituent0BalanceBefore = IERC20(vaults[0]).balanceOf(tradeIssuerAddress);
        uint256 constituent1BalanceBefore = IERC20(vaults[1]).balanceOf(tradeIssuerAddress);

        chamberQuantities[0] = constituentQuantity0;
        chamberQuantities[1] = constituentQuantity1;
        chamber = chamberFactory.getChamberWithCustomTokens(vaults, chamberQuantities);
        chamberAddress = address(chamber);

        uint256 pricePerShare0 = IVault(vaults[0]).pricePerShare();
        uint256 depositAmount0 =
            mintAmount.preciseMulCeil(chamberQuantities[0], 18).preciseMulCeil(pricePerShare0, 6);

        vaultQuantities[0] = (depositAmount0 * 100001) / 100000;
        vaultQuantities[1] = 0;

        deal(vaultAssets[0], tradeIssuerAddress, vaultQuantities[0]);
        deal(vaultAssets[1], tradeIssuerAddress, vaultQuantities[1]);

        vm.expectRevert(bytes("Deposit amount cannot be zero"));

        tradeIssuer.depositConstituentsInVault(
            vaults, vaultAssets, vaultQuantities, IChamber(chamberAddress), mintAmount
        );

        uint256 constituent0BalanceAfter = IERC20(vaults[0]).balanceOf(tradeIssuerAddress);
        uint256 constituent1BalanceAfter = IERC20(vaults[1]).balanceOf(tradeIssuerAddress);

        assertEq(IERC20(vaultAssets[0]).balanceOf(tradeIssuerAddress), vaultQuantities[0]);
        assertEq(IERC20(vaultAssets[1]).balanceOf(tradeIssuerAddress), vaultQuantities[1]);
        assertGe(constituent0BalanceAfter - constituent0BalanceBefore, 0);
        assertGe(constituent1BalanceAfter - constituent1BalanceBefore, 0);
    }

    /**
     * [REVERT] Should revert with zero mintAMount. This condition isn't supposed to happen
     * because there's a check for the mint amount at main external functions. Deposit amounts are sent.
     */
    function testCannotSuccessDepositInVaults0MintAmountAndDepositAmounts(
        uint64 constituentQuantity0,
        uint64 constituentQuantity1
    ) public {
        uint64 mintAmount = 0;
        vm.assume(constituentQuantity0 > 10 ** 4); // 0.01 USDC
        vm.assume(constituentQuantity0 < 1000 * (10 ** 6)); // 1000 USDC
        vm.assume(constituentQuantity1 > 10 ** 16); // 0.01 DAI
        vm.assume(constituentQuantity1 < 1000 * (10 ** 18)); // 1000 USDC

        uint256 constituent0BalanceBefore = IERC20(vaults[0]).balanceOf(tradeIssuerAddress);
        uint256 constituent1BalanceBefore = IERC20(vaults[1]).balanceOf(tradeIssuerAddress);

        chamberQuantities[0] = constituentQuantity0;
        chamberQuantities[1] = constituentQuantity1;
        chamber = chamberFactory.getChamberWithCustomTokens(vaults, chamberQuantities);
        chamberAddress = address(chamber);

        uint256 pricePerShare0 = IVault(vaults[0]).pricePerShare();
        uint256 pricePerShare1 = IVault(vaults[1]).pricePerShare();
        uint256 depositAmount0 =
            mintAmount.preciseMulCeil(chamberQuantities[0], 18).preciseMulCeil(pricePerShare0, 6);

        uint256 depositAmount1 =
            mintAmount.preciseMulCeil(chamberQuantities[1], 18).preciseMulCeil(pricePerShare1, 18);

        vaultQuantities[0] = (depositAmount0 * 100001) / 100000;
        vaultQuantities[1] = (depositAmount1 * 100001) / 100000;

        deal(vaultAssets[0], tradeIssuerAddress, vaultQuantities[0]);
        deal(vaultAssets[1], tradeIssuerAddress, vaultQuantities[1]);

        vm.expectRevert(bytes("Quantity is zero"));
        tradeIssuer.depositConstituentsInVault(
            vaults, vaultAssets, vaultQuantities, IChamber(chamberAddress), mintAmount
        );

        uint256 constituent0BalanceAfter = IERC20(vaults[0]).balanceOf(tradeIssuerAddress);
        uint256 constituent1BalanceAfter = IERC20(vaults[1]).balanceOf(tradeIssuerAddress);

        assertEq(IERC20(vaultAssets[0]).balanceOf(tradeIssuerAddress), vaultQuantities[0]);
        assertEq(IERC20(vaultAssets[1]).balanceOf(tradeIssuerAddress), vaultQuantities[1]);
        assertGe(constituent0BalanceAfter - constituent0BalanceBefore, 0);
        assertGe(constituent1BalanceAfter - constituent1BalanceBefore, 0);
    }

    /**
     * [REVERT] Should revert with zero mintAMount. This condition isn't supposed to happen
     * because there's a check for the mint amount at main external functions. Deposit amounts are
     * also zero in this case.
     */
    function testCannotDepositInVaults0MintAmountWithoutDepositAmounts(
        uint64 constituentQuantity0,
        uint64 constituentQuantity1
    ) public {
        uint64 mintAmount = 0;
        vm.assume(constituentQuantity0 > 10 ** 4); // 0.01 USDC
        vm.assume(constituentQuantity0 < 1000 * (10 ** 6)); // 1000 USDC
        vm.assume(constituentQuantity1 > 10 ** 16); // 0.01 DAI
        vm.assume(constituentQuantity1 < 1000 * (10 ** 18)); // 1000 USDC

        uint256 constituent0BalanceBefore = IERC20(vaults[0]).balanceOf(tradeIssuerAddress);
        uint256 constituent1BalanceBefore = IERC20(vaults[1]).balanceOf(tradeIssuerAddress);

        chamberQuantities[0] = constituentQuantity0;
        chamberQuantities[1] = constituentQuantity1;
        chamber = chamberFactory.getChamberWithCustomTokens(vaults, chamberQuantities);
        chamberAddress = address(chamber);

        vaultQuantities[0] = 0;
        vaultQuantities[1] = 0;

        deal(vaultAssets[0], tradeIssuerAddress, vaultQuantities[0]);
        deal(vaultAssets[1], tradeIssuerAddress, vaultQuantities[1]);

        vm.expectRevert(bytes("Quantity is zero"));
        tradeIssuer.depositConstituentsInVault(
            vaults, vaultAssets, vaultQuantities, IChamber(chamberAddress), mintAmount
        );

        uint256 constituent0BalanceAfter = IERC20(vaults[0]).balanceOf(tradeIssuerAddress);
        uint256 constituent1BalanceAfter = IERC20(vaults[1]).balanceOf(tradeIssuerAddress);

        assertEq(IERC20(vaultAssets[0]).balanceOf(tradeIssuerAddress), vaultQuantities[0]);
        assertEq(IERC20(vaultAssets[1]).balanceOf(tradeIssuerAddress), vaultQuantities[1]);
        assertGe(constituent0BalanceAfter - constituent0BalanceBefore, 0);
        assertGe(constituent1BalanceAfter - constituent1BalanceBefore, 0);
    }

    /*//////////////////////////////////////////////////////////////
                              SUCCESS
    //////////////////////////////////////////////////////////////*/

    /**
     * [SUCCESS] Should deposit the required amounts and get the quantities needed for mint.
     */
    function testSuccessDepositInVaults(
        uint64 mintAmount,
        uint64 constituentQuantity0,
        uint64 constituentQuantity1
    ) public {
        vm.assume(mintAmount > 0);
        vm.assume(constituentQuantity0 > 10 ** 4); // 0.01 USDC
        vm.assume(constituentQuantity0 < 1000 * (10 ** 6)); // 1000 USDC
        vm.assume(constituentQuantity1 > 10 ** 16); // 0.01 DAI
        vm.assume(constituentQuantity1 < 1000 * (10 ** 18)); // 1000 USDC

        uint256 constituent0BalanceBefore = IERC20(vaults[0]).balanceOf(tradeIssuerAddress);
        uint256 constituent1BalanceBefore = IERC20(vaults[1]).balanceOf(tradeIssuerAddress);

        chamberQuantities[0] = constituentQuantity0;
        chamberQuantities[1] = constituentQuantity1;
        chamber = chamberFactory.getChamberWithCustomTokens(vaults, chamberQuantities);
        chamberAddress = address(chamber);

        uint256 pricePerShare0 = IVault(vaults[0]).pricePerShare();
        uint256 pricePerShare1 = IVault(vaults[1]).pricePerShare();
        uint256 depositAmount0 =
            mintAmount.preciseMulCeil(chamberQuantities[0], 18).preciseMulCeil(pricePerShare0, 6);

        uint256 depositAmount1 =
            mintAmount.preciseMulCeil(chamberQuantities[1], 18).preciseMulCeil(pricePerShare1, 18);

        vaultQuantities[0] = (depositAmount0 * 100001) / 100000;
        vaultQuantities[1] = (depositAmount1 * 100001) / 100000;

        deal(vaultAssets[0], tradeIssuerAddress, vaultQuantities[0]);
        deal(vaultAssets[1], tradeIssuerAddress, vaultQuantities[1]);

        tradeIssuer.depositConstituentsInVault(
            vaults, vaultAssets, vaultQuantities, IChamber(chamberAddress), mintAmount
        );

        uint256 constituent0BalanceAfter = IERC20(vaults[0]).balanceOf(tradeIssuerAddress);
        uint256 constituent1BalanceAfter = IERC20(vaults[1]).balanceOf(tradeIssuerAddress);

        assertEq(IERC20(vaultAssets[0]).balanceOf(tradeIssuerAddress), 0);
        assertEq(IERC20(vaultAssets[1]).balanceOf(tradeIssuerAddress), 0);
        assertGe(
            constituent0BalanceAfter - constituent0BalanceBefore,
            (mintAmount.preciseMulCeil(chamberQuantities[0], 18))
        );
        assertGe(
            constituent1BalanceAfter - constituent1BalanceBefore,
            (mintAmount.preciseMulCeil(chamberQuantities[1], 18))
        );
    }

    /**
     * [SUCCESS] Should deposit de required amounts and get the quantities needed for mint.
     */
    function testSuccessDepositInVaultsWithLessVaultsThanVaultsAssets(
        uint64 mintAmount,
        uint64 constituentQuantity0,
        uint64 constituentQuantity1
    ) public {
        vm.assume(mintAmount > 0);
        vm.assume(constituentQuantity0 > 10 ** 4); // 0.01 USDC
        vm.assume(constituentQuantity0 < 1000 * (10 ** 6)); // 1000 USDC
        vm.assume(constituentQuantity1 > 10 ** 16); // 0.01 DAI
        vm.assume(constituentQuantity1 < 1000 * (10 ** 18)); // 1000 USDC

        uint256 constituent0BalanceBefore = IERC20(vaults[0]).balanceOf(tradeIssuerAddress);
        uint256 constituent1BalanceBefore = IERC20(vaults[1]).balanceOf(tradeIssuerAddress);

        chamberQuantities[0] = constituentQuantity0;
        chamberQuantities[1] = constituentQuantity1;
        chamber = chamberFactory.getChamberWithCustomTokens(vaults, chamberQuantities);
        chamberAddress = address(chamber);

        uint256 pricePerShare0 = IVault(vaults[0]).pricePerShare();
        uint256 pricePerShare1 = IVault(vaults[1]).pricePerShare();
        uint256 depositAmount0 =
            mintAmount.preciseMulCeil(chamberQuantities[0], 18).preciseMulCeil(pricePerShare0, 6);

        uint256 depositAmount1 =
            mintAmount.preciseMulCeil(chamberQuantities[1], 18).preciseMulCeil(pricePerShare1, 18);

        vaultQuantities[0] = (depositAmount0 * 100001) / 100000;
        vaultQuantities[1] = (depositAmount1 * 100001) / 100000;

        deal(vaultAssets[0], tradeIssuerAddress, vaultQuantities[0]);
        deal(vaultAssets[1], tradeIssuerAddress, vaultQuantities[1]);

        address[] memory onlyOneVault = new address[](1);
        onlyOneVault[0] = yUSDC;

        tradeIssuer.depositConstituentsInVault(
            onlyOneVault, vaultAssets, vaultQuantities, IChamber(chamberAddress), mintAmount
        );

        assertEq(IERC20(vaultAssets[0]).balanceOf(tradeIssuerAddress), 0);
        assertEq(IERC20(vaultAssets[1]).balanceOf(tradeIssuerAddress), vaultQuantities[1]);
        assertGe(
            IERC20(vaults[0]).balanceOf(tradeIssuerAddress) - constituent0BalanceBefore,
            (mintAmount.preciseMulCeil(chamberQuantities[0], 18))
        );
        assertGe(IERC20(vaults[1]).balanceOf(tradeIssuerAddress) - constituent1BalanceBefore, 0);
    }

    /**
     * [SUCCESS] Should pass without making deposits because all the vaults related arrays
     * are empty. There's a flag thet checks if deposits are required at mint but it's still
     * a possible scenario.
     */
    function testSuccessDepositInVaultsWithEmptyVaultsArrays(
        uint64 mintAmount,
        uint64 constituentQuantity0,
        uint64 constituentQuantity1
    ) public {
        vm.assume(mintAmount > 0);
        vm.assume(constituentQuantity0 > 10 ** 4); // 0.01 USDC
        vm.assume(constituentQuantity0 < 1000 * (10 ** 6)); // 1000 USDC
        vm.assume(constituentQuantity1 > 10 ** 16); // 0.01 DAI
        vm.assume(constituentQuantity1 < 1000 * (10 ** 18)); // 1000 USDC

        chamberQuantities[0] = constituentQuantity0;
        chamberQuantities[1] = constituentQuantity1;
        chamber = chamberFactory.getChamberWithCustomTokens(vaults, chamberQuantities);
        chamberAddress = address(chamber);

        address[] memory emptyVaults = new address[](0);
        address[] memory emptyVaultAssets = new address[](0);
        uint256[] memory emptyVaultQuantities = new uint256[](0);

        tradeIssuer.depositConstituentsInVault(
            emptyVaults,
            emptyVaultAssets,
            emptyVaultQuantities,
            IChamber(chamberAddress),
            mintAmount
        );
    }

    /**
     * [SUCCESS] Should pass even if yVault tokens issued are more than the required amount for
     * minting.
     */
    function testDepositWithOverboughtAssets(
        uint64 mintAmount,
        uint64 constituentQuantity0,
        uint64 constituentQuantity1
    ) public {
        vm.assume(mintAmount > 0);
        vm.assume(constituentQuantity0 > 10 ** 4); // 0.01 USDC
        vm.assume(constituentQuantity0 < 1000 * (10 ** 6)); // 1000 USDC
        vm.assume(constituentQuantity1 > 10 ** 16); // 0.01 DAI
        vm.assume(constituentQuantity1 < 1000 * (10 ** 18)); // 1000 USDC

        uint256 constituent0BalanceBefore = IERC20(vaults[0]).balanceOf(tradeIssuerAddress);
        uint256 constituent1BalanceBefore = IERC20(vaults[1]).balanceOf(tradeIssuerAddress);

        chamberQuantities[0] = constituentQuantity0;
        chamberQuantities[1] = constituentQuantity1;
        chamber = chamberFactory.getChamberWithCustomTokens(vaults, chamberQuantities);
        chamberAddress = address(chamber);

        uint256 pricePerShare0 = IVault(vaults[0]).pricePerShare();
        uint256 pricePerShare1 = IVault(vaults[1]).pricePerShare();
        uint256 depositAmount0 =
            mintAmount.preciseMulCeil(chamberQuantities[0], 18).preciseMulCeil(pricePerShare0, 6);

        uint256 depositAmount1 =
            mintAmount.preciseMulCeil(chamberQuantities[1], 18).preciseMulCeil(pricePerShare1, 18);

        vaultQuantities[0] = ((depositAmount0 * 100001) / 100000) * 10;
        vaultQuantities[1] = ((depositAmount1 * 100001) / 100000) * 10;

        deal(vaultAssets[0], tradeIssuerAddress, vaultQuantities[0]);
        deal(vaultAssets[1], tradeIssuerAddress, vaultQuantities[1]);

        tradeIssuer.depositConstituentsInVault(
            vaults, vaultAssets, vaultQuantities, IChamber(chamberAddress), mintAmount
        );

        assertEq(IERC20(vaultAssets[0]).balanceOf(tradeIssuerAddress), 0);
        assertEq(IERC20(vaultAssets[1]).balanceOf(tradeIssuerAddress), 0);
        assertGe(
            IERC20(vaults[0]).balanceOf(tradeIssuerAddress) - constituent0BalanceBefore,
            (mintAmount.preciseMulCeil(chamberQuantities[0], 18))
        );
        assertGe(IERC20(vaults[1]).balanceOf(tradeIssuerAddress) - constituent1BalanceBefore, 0);
    }
}
