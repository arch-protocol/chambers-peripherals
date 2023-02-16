// Copyright 2022 Smash Works Inc.
// SPDX-License-Identifier: Apache License 2.0
pragma solidity ^0.8.17.0;

import "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ExposedTradeIssuer} from "test/utils/ExposedTradeIssuer.sol";
import {IChamber} from "chambers/interfaces/IChamber.sol";
import {IIssuerWizard} from "chambers/interfaces/IIssuerWizard.sol";
import {IssuerWizard} from "chambers/IssuerWizard.sol";
import {ChamberGod} from "chambers/ChamberGod.sol";
import {Chamber} from "chambers/Chamber.sol";
import {PreciseUnitMath} from "chambers/lib/PreciseUnitMath.sol";

contract TradeIssuerIntegrationIngernalCheckAndIncreaseAllowanceOfConstituentsTest is Test {
    using SafeERC20 for IERC20;
    using PreciseUnitMath for uint256;

    /*//////////////////////////////////////////////////////////////
                              VARIABLES
    //////////////////////////////////////////////////////////////*/
    ExposedTradeIssuer public tradeIssuer;
    ChamberGod public chamberGod;
    Chamber public chamber;
    IssuerWizard public issuerWizard;
    address payable public dexAgg = payable(address(0x1));
    address public chamberAddress;
    address public issuerWizardAddress;
    address public tradeIssuerAddress;
    address public dAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F; // dAI on ETH
    address public yFI = 0x0bc529c00C6401aEF6D220BE8C6Ea1667F6Ad93e; // YFI on ETH
    address public wETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2; // WETH on ETH
    address public inputToken = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48; // USDC on ETH
    address[] public constituents = new address[](2);
    uint256[] public constituentsQuantities = new uint256[](2);
    address[] public wizards = new address[](1);
    address[] public managers = new address[](0);

    /*//////////////////////////////////////////////////////////////
                              SET UP
    //////////////////////////////////////////////////////////////*/

    function setUp() public {
        tradeIssuer = new ExposedTradeIssuer(dexAgg, wETH);

        tradeIssuerAddress = address(tradeIssuer);
        vm.label(tradeIssuerAddress, "TradeIssuer");
        constituents[0] = dAI;
        constituents[1] = yFI;

        chamberGod = new ChamberGod();
        issuerWizard = new IssuerWizard(address(chamberGod));
        chamberGod.addWizard(address(issuerWizard));

        issuerWizardAddress = address(issuerWizard);

        wizards[0] = issuerWizardAddress;
    }

    /*//////////////////////////////////////////////////////////////
                              REVERT
    //////////////////////////////////////////////////////////////*/

    /**
     * [REVERT] Should revert because the mint amount is zero.
     */
    function testCannotCheckAndIncreaseWhenMintAmountIsZero(
        uint256 constituent0Quantity,
        uint256 constituent1Quantity
    ) public {
        uint256 mintAmount = 0;
        vm.assume(constituent0Quantity > 0);
        vm.assume(constituent0Quantity < type(uint64).max);
        vm.assume(constituent1Quantity > 0);
        vm.assume(constituent1Quantity < type(uint64).max);

        constituentsQuantities[0] = constituent0Quantity;
        constituentsQuantities[1] = constituent1Quantity;

        chamber = Chamber(
            chamberGod.createChamber(
                "name", "symbol", constituents, constituentsQuantities, wizards, managers
            )
        );
        chamberAddress = address(chamber);

        vm.expectRevert(bytes("Chamber amount cannot be zero"));
        tradeIssuer.checkAndIncreaseAllowanceOfConstituents(
            IChamber(chamberAddress), IIssuerWizard(issuerWizardAddress), mintAmount
        );

        assertEq(IERC20(dAI).allowance(tradeIssuerAddress, issuerWizardAddress), 0);
        assertEq(IERC20(yFI).allowance(tradeIssuerAddress, issuerWizardAddress), 0);
    }

    /*//////////////////////////////////////////////////////////////
                              SUCCESS
    //////////////////////////////////////////////////////////////*/

    /**
     * [SUCCESS] Should check allowance and increase it to max. when previous allowance is zero.
     */
    function testCheckAndIncreaseAllowanceToMaxWhenCurrentAllowanceIsZero(
        uint256 constituent0Quantity,
        uint256 constituent1Quantity,
        uint64 mintAmount
    ) public {
        vm.assume(mintAmount > 0);
        vm.assume(mintAmount < type(uint160).max);
        vm.assume(constituent0Quantity > 0);
        vm.assume(constituent0Quantity < type(uint64).max);
        vm.assume(constituent1Quantity > 0);
        vm.assume(constituent1Quantity < type(uint64).max);

        constituentsQuantities[0] = constituent0Quantity;
        constituentsQuantities[1] = constituent1Quantity;

        chamber = Chamber(
            chamberGod.createChamber(
                "name", "symbol", constituents, constituentsQuantities, wizards, managers
            )
        );
        chamberAddress = address(chamber);

        vm.expectCall(
            issuerWizardAddress,
            abi.encodeCall(
                IIssuerWizard(issuerWizardAddress).getConstituentsQuantitiesForIssuance,
                (IChamber(chamberAddress), mintAmount)
            )
        );

        vm.expectCall(
            dAI, abi.encodeCall(IERC20(dAI).allowance, (tradeIssuerAddress, issuerWizardAddress))
        );
        vm.expectCall(
            dAI, abi.encodeCall(IERC20(dAI).approve, (issuerWizardAddress, type(uint256).max))
        );
        vm.expectCall(
            yFI, abi.encodeCall(IERC20(yFI).allowance, (tradeIssuerAddress, issuerWizardAddress))
        );
        vm.expectCall(
            yFI, abi.encodeCall(IERC20(yFI).approve, (issuerWizardAddress, type(uint256).max))
        );

        tradeIssuer.checkAndIncreaseAllowanceOfConstituents(
            IChamber(chamberAddress), IIssuerWizard(issuerWizardAddress), mintAmount
        );

        assertEq(IERC20(dAI).allowance(tradeIssuerAddress, issuerWizardAddress), type(uint256).max);
        assertEq(IERC20(yFI).allowance(tradeIssuerAddress, issuerWizardAddress), type(uint256).max);
    }

    /**
     * [SUCCESS] Should check allowance and increase it to max. when there's a previous allowance
     * that is less than the required amount.
     */
    function testCheckAndIncreaseAllowanceToMaxWhenCurrentAllowanceIsNotEnough(
        uint256 constituent0Quantity,
        uint256 constituent1Quantity,
        uint256 randomApproveAmount,
        uint64 mintAmount
    ) public {
        vm.assume(mintAmount > 0);
        vm.assume(mintAmount < type(uint160).max);
        vm.assume(constituent0Quantity > 0);
        vm.assume(constituent0Quantity < type(uint64).max);
        vm.assume(constituent1Quantity > 0);
        vm.assume(constituent1Quantity < type(uint64).max);

        constituentsQuantities[0] = constituent0Quantity;
        constituentsQuantities[1] = constituent1Quantity;

        vm.assume(randomApproveAmount > 0);
        vm.assume(randomApproveAmount < constituentsQuantities[0].preciseMulCeil(mintAmount, 18));

        chamber = Chamber(
            chamberGod.createChamber(
                "name", "symbol", constituents, constituentsQuantities, wizards, managers
            )
        );
        chamberAddress = address(chamber);

        vm.expectCall(
            issuerWizardAddress,
            abi.encodeCall(
                IIssuerWizard(issuerWizardAddress).getConstituentsQuantitiesForIssuance,
                (IChamber(chamberAddress), mintAmount)
            )
        );

        vm.prank(tradeIssuerAddress);
        IERC20(dAI).approve(issuerWizardAddress, randomApproveAmount);

        vm.expectCall(
            dAI, abi.encodeCall(IERC20(dAI).allowance, (tradeIssuerAddress, issuerWizardAddress))
        );
        vm.expectCall(
            dAI, abi.encodeCall(IERC20(dAI).approve, (issuerWizardAddress, type(uint256).max))
        );
        vm.expectCall(
            yFI, abi.encodeCall(IERC20(yFI).allowance, (tradeIssuerAddress, issuerWizardAddress))
        );
        vm.expectCall(
            yFI, abi.encodeCall(IERC20(yFI).approve, (issuerWizardAddress, type(uint256).max))
        );

        tradeIssuer.checkAndIncreaseAllowanceOfConstituents(
            IChamber(chamberAddress), IIssuerWizard(issuerWizardAddress), mintAmount
        );

        assertEq(IERC20(dAI).allowance(tradeIssuerAddress, issuerWizardAddress), type(uint256).max);
        assertEq(IERC20(yFI).allowance(tradeIssuerAddress, issuerWizardAddress), type(uint256).max);
    }

    /**
     * [SUCCESS] Should NOT call increase allowance when having enough in one token
     */

    function testCheckAndIncreaseAllowanceShouldNotIncreaseWhenCurrentAllowanceIsEnough(
        uint256 constituent0Quantity,
        uint256 constituent1Quantity,
        uint256 mintAmount
    ) public {
        vm.assume(mintAmount > 0);
        vm.assume(mintAmount < type(uint160).max);
        vm.assume(constituent0Quantity > 0);
        vm.assume(constituent0Quantity < type(uint64).max);
        vm.assume(constituent1Quantity > 0);
        vm.assume(constituent1Quantity < type(uint64).max);

        constituentsQuantities[0] = constituent0Quantity;
        constituentsQuantities[1] = constituent1Quantity;

        vm.prank(tradeIssuerAddress);
        IERC20(dAI).approve(
            issuerWizardAddress, constituentsQuantities[0].preciseMulCeil(mintAmount, 18) - 1
        ); // Not enough

        vm.prank(tradeIssuerAddress);
        IERC20(yFI).approve(issuerWizardAddress, type(uint256).max);

        chamber = Chamber(
            chamberGod.createChamber(
                "name", "symbol", constituents, constituentsQuantities, wizards, managers
            )
        );
        chamberAddress = address(chamber);

        vm.expectCall(
            issuerWizardAddress,
            abi.encodeCall(
                IIssuerWizard(issuerWizardAddress).getConstituentsQuantitiesForIssuance,
                (IChamber(chamberAddress), mintAmount)
            )
        );

        vm.expectCall(
            dAI, abi.encodeCall(IERC20(dAI).allowance, (tradeIssuerAddress, issuerWizardAddress))
        );
        vm.expectCall(
            dAI, abi.encodeCall(IERC20(dAI).approve, (issuerWizardAddress, type(uint256).max))
        );
        vm.expectCall(
            yFI, abi.encodeCall(IERC20(yFI).allowance, (tradeIssuerAddress, issuerWizardAddress))
        );

        tradeIssuer.checkAndIncreaseAllowanceOfConstituents(
            IChamber(chamberAddress), IIssuerWizard(issuerWizardAddress), mintAmount
        );

        assertEq(IERC20(dAI).allowance(tradeIssuerAddress, issuerWizardAddress), type(uint256).max);
        assertEq(IERC20(yFI).allowance(tradeIssuerAddress, issuerWizardAddress), type(uint256).max);
    }

    /**
     * [SUCCESS] Should NOT call increase allowance when having max allowance. Allowance
     * should not change either.
     */
    function testCheckAndIncreaseAllowanceShouldNotChangeWhenCurrentAllowanceIsMax(
        uint256 constituent0Quantity,
        uint256 constituent1Quantity,
        uint256 mintAmount
    ) public {
        vm.assume(mintAmount > 0);
        vm.assume(mintAmount < type(uint160).max);
        vm.assume(constituent0Quantity > 0);
        vm.assume(constituent0Quantity < type(uint64).max);
        vm.assume(constituent1Quantity > 0);
        vm.assume(constituent1Quantity < type(uint64).max);

        constituentsQuantities[0] = constituent0Quantity;
        constituentsQuantities[1] = constituent1Quantity;

        vm.prank(tradeIssuerAddress);
        IERC20(dAI).approve(issuerWizardAddress, type(uint256).max);

        vm.prank(tradeIssuerAddress);
        IERC20(yFI).approve(issuerWizardAddress, type(uint256).max);

        chamber = Chamber(
            chamberGod.createChamber(
                "name", "symbol", constituents, constituentsQuantities, wizards, managers
            )
        );
        chamberAddress = address(chamber);

        vm.expectCall(
            issuerWizardAddress,
            abi.encodeCall(
                IIssuerWizard(issuerWizardAddress).getConstituentsQuantitiesForIssuance,
                (IChamber(chamberAddress), mintAmount)
            )
        );

        vm.expectCall(
            dAI, abi.encodeCall(IERC20(dAI).allowance, (tradeIssuerAddress, issuerWizardAddress))
        );
        vm.expectCall(
            yFI, abi.encodeCall(IERC20(yFI).allowance, (tradeIssuerAddress, issuerWizardAddress))
        );

        tradeIssuer.checkAndIncreaseAllowanceOfConstituents(
            IChamber(chamberAddress), IIssuerWizard(issuerWizardAddress), mintAmount
        );

        assertEq(IERC20(dAI).allowance(tradeIssuerAddress, issuerWizardAddress), type(uint256).max);
        assertEq(IERC20(yFI).allowance(tradeIssuerAddress, issuerWizardAddress), type(uint256).max);
    }
}
