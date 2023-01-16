// Copyright 2022 Smash Works Inc.
// SPDX-License-Identifier: Apache License 2.0
pragma solidity ^0.8.17.0;

import "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ExposedTradeIssuer} from "test/utils/ExposedTradeIssuer.sol";
import {IChamber} from "chambers/interfaces/IChamber.sol";
import {IIssuerWizard} from "chambers/interfaces/IIssuerWizard.sol";
import {PreciseUnitMath} from "chambers/lib/PreciseUnitMath.sol";

contract TradeIssuerUnitInternalCheckAndIncreaseAllowanceOfConstituentsTest is Test {
    using SafeERC20 for IERC20;
    using PreciseUnitMath for uint256;

    /*//////////////////////////////////////////////////////////////
                              VARIABLES
    //////////////////////////////////////////////////////////////*/
    ExposedTradeIssuer public tradeIssuer;
    address payable public dexAgg = payable(address(0x1));
    address public chamberAddress = address(0x2);
    address public issuerWizardAddress = address(0x3);
    address public tradeIssuerAddress;
    address public dAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F; // dAI on ETH
    address public yFI = 0x0bc529c00C6401aEF6D220BE8C6Ea1667F6Ad93e; // YFI on ETH
    address public wETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2; // WETH on ETH
    address public inputToken = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48; // USDC on ETH
    address[] public constituents = new address[](2);
    uint256[] public constituentsIssueQuantities = new uint256[](2);

    /*//////////////////////////////////////////////////////////////
                              SET UP
    //////////////////////////////////////////////////////////////*/

    function setUp() public {
        tradeIssuer = new ExposedTradeIssuer(dexAgg, wETH);
        tradeIssuerAddress = address(tradeIssuer);
        vm.label(tradeIssuerAddress, "TradeIssuer");
        constituents[0] = dAI;
        constituents[1] = yFI;
    }

    /*//////////////////////////////////////////////////////////////
                              REVERT
    //////////////////////////////////////////////////////////////*/

    /**
     * [REVERT] Should revert if 'requiredConstituentsQuantities' array
     * has less elements than 'requiredConstituents'.
     */
    function testCannotCheckWithDifferentArrayLengths(
        uint256 constituent0Quantity,
        uint64 mintAmount
    ) public {
        vm.assume(mintAmount > 0);
        vm.assume(mintAmount < type(uint160).max);
        vm.assume(constituent0Quantity > 0);
        vm.assume(constituent0Quantity < type(uint64).max);

        uint256[] memory constituentIssuanceOneElement = new uint256[](1);
        constituentIssuanceOneElement[0] = constituent0Quantity;

        vm.mockCall(
            issuerWizardAddress,
            abi.encodeWithSelector(
                IIssuerWizard(issuerWizardAddress).getConstituentsQuantitiesForIssuance.selector,
                chamberAddress,
                mintAmount
            ),
            abi.encode(constituents, constituentIssuanceOneElement)
        );

        vm.expectCall(
            dAI, abi.encodeCall(IERC20(dAI).allowance, (tradeIssuerAddress, issuerWizardAddress))
        );
        vm.expectCall(
            dAI, abi.encodeCall(IERC20(dAI).approve, (issuerWizardAddress, type(uint256).max))
        );

        vm.expectRevert(stdError.indexOOBError); //Index Out of bounds stdError
        tradeIssuer.checkAndIncreaseAllowanceOfConstituents(
            IChamber(chamberAddress), IIssuerWizard(issuerWizardAddress), mintAmount
        );

        assertEq(IERC20(dAI).allowance(tradeIssuerAddress, issuerWizardAddress), 0);
        assertEq(IERC20(yFI).allowance(tradeIssuerAddress, issuerWizardAddress), 0);
    }

    /**
     * [REVERT] Should revert because quantities are zero.
     */
    function testCannotCheckAndNoIncreaseWhenZeroQuantities(uint256 mintAmount) public {
        vm.assume(mintAmount > 0);
        vm.assume(mintAmount < type(uint160).max);

        constituentsIssueQuantities[0] = 0;
        constituentsIssueQuantities[1] = 0;

        vm.mockCall(
            issuerWizardAddress,
            abi.encodeWithSelector(
                IIssuerWizard(issuerWizardAddress).getConstituentsQuantitiesForIssuance.selector,
                chamberAddress,
                mintAmount
            ),
            abi.encode(constituents, constituentsIssueQuantities)
        );

        vm.expectCall(
            dAI, abi.encodeCall(IERC20(dAI).allowance, (tradeIssuerAddress, issuerWizardAddress))
        );
        vm.expectCall(
            yFI, abi.encodeCall(IERC20(yFI).allowance, (tradeIssuerAddress, issuerWizardAddress))
        );

        vm.expectRevert("Required amount cannot be zero");
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
     * [SUCCESS] Should check allowance and increase when allowance is zero.
     */
    function testCheckAndIncreaseWhenHavingZeroAllowance(
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

        constituentsIssueQuantities[0] = constituent0Quantity.preciseMulCeil(mintAmount, 18);
        constituentsIssueQuantities[1] = constituent1Quantity.preciseMulCeil(mintAmount, 18);

        vm.mockCall(
            issuerWizardAddress,
            abi.encodeWithSelector(
                IIssuerWizard(issuerWizardAddress).getConstituentsQuantitiesForIssuance.selector,
                chamberAddress,
                mintAmount
            ),
            abi.encode(constituents, constituentsIssueQuantities)
        );

        vm.expectCall(
            dAI, abi.encodeCall(IERC20(dAI).allowance, (tradeIssuerAddress, issuerWizardAddress))
        );
        vm.expectCall(
            dAI, abi.encodeCall(IERC20(yFI).approve, (issuerWizardAddress, type(uint256).max))
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
     * [SUCCESS] Should check allowance and increase when there's a previous allowance
     * that is less than the required amount.
     */
    function testCheckAndIncreaseWithoutEnoughCurrentAllowance(
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

        constituentsIssueQuantities[0] = constituent0Quantity.preciseMulCeil(mintAmount, 18);
        constituentsIssueQuantities[1] = constituent1Quantity.preciseMulCeil(mintAmount, 18);

        vm.assume(randomApproveAmount > 0);
        vm.assume(randomApproveAmount < constituentsIssueQuantities[0]);

        vm.mockCall(
            issuerWizardAddress,
            abi.encodeWithSelector(
                IIssuerWizard(issuerWizardAddress).getConstituentsQuantitiesForIssuance.selector,
                chamberAddress,
                mintAmount
            ),
            abi.encode(constituents, constituentsIssueQuantities)
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
     * [SUCCESS] Should not call the increase allowance functions from ERC20
     * since there's enough allowance already.
     */
    function testCheckAndNoIncreaseWhenHavingEnoughAllowance(
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

        constituentsIssueQuantities[0] = constituent0Quantity.preciseMulCeil(mintAmount, 18);
        constituentsIssueQuantities[1] = constituent1Quantity.preciseMulCeil(mintAmount, 18);

        vm.mockCall(
            issuerWizardAddress,
            abi.encodeWithSelector(
                IIssuerWizard(issuerWizardAddress).getConstituentsQuantitiesForIssuance.selector,
                chamberAddress,
                mintAmount
            ),
            abi.encode(constituents, constituentsIssueQuantities)
        );

        vm.prank(tradeIssuerAddress);
        IERC20(dAI).approve(issuerWizardAddress, constituentsIssueQuantities[0] + 1);

        vm.prank(tradeIssuerAddress);
        IERC20(yFI).approve(issuerWizardAddress, constituentsIssueQuantities[1] + 1);

        vm.expectCall(
            dAI, abi.encodeCall(IERC20(dAI).allowance, (tradeIssuerAddress, issuerWizardAddress))
        );
        vm.expectCall(
            yFI, abi.encodeCall(IERC20(yFI).allowance, (tradeIssuerAddress, issuerWizardAddress))
        );

        tradeIssuer.checkAndIncreaseAllowanceOfConstituents(
            IChamber(chamberAddress), IIssuerWizard(issuerWizardAddress), mintAmount
        );

        // Same allowance since all is mock calls
        assertEq(
            IERC20(dAI).allowance(tradeIssuerAddress, issuerWizardAddress),
            constituentsIssueQuantities[0] + 1
        );
        assertEq(
            IERC20(yFI).allowance(tradeIssuerAddress, issuerWizardAddress),
            constituentsIssueQuantities[1] + 1
        );
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

        constituentsIssueQuantities[0] = constituent0Quantity.preciseMulCeil(mintAmount, 18);
        constituentsIssueQuantities[1] = constituent1Quantity.preciseMulCeil(mintAmount, 18);

        vm.mockCall(
            issuerWizardAddress,
            abi.encodeWithSelector(
                IIssuerWizard(issuerWizardAddress).getConstituentsQuantitiesForIssuance.selector,
                chamberAddress,
                mintAmount
            ),
            abi.encode(constituents, constituentsIssueQuantities)
        );

        vm.prank(tradeIssuerAddress);
        IERC20(dAI).approve(issuerWizardAddress, type(uint256).max);

        vm.prank(tradeIssuerAddress);
        IERC20(yFI).approve(issuerWizardAddress, type(uint256).max);

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

    /**
     * [SUCCESS] Shouldn't increase allowance beacause constituents and quantites are empty
     */
    function testCheckAndNoIncreaseWhenZeroQuantitiesAndConstituents(uint256 mintAmount) public {
        vm.assume(mintAmount > 0);
        address[] memory emptyConstituents = new address[](0);
        uint256[] memory emptyQuantities = new uint256[](0);

        vm.mockCall(
            issuerWizardAddress,
            abi.encodeWithSelector(
                IIssuerWizard(issuerWizardAddress).getConstituentsQuantitiesForIssuance.selector,
                chamberAddress,
                mintAmount
            ),
            abi.encode(emptyConstituents, emptyQuantities)
        );

        tradeIssuer.checkAndIncreaseAllowanceOfConstituents(
            IChamber(chamberAddress), IIssuerWizard(issuerWizardAddress), mintAmount
        );

        assertEq(IERC20(dAI).allowance(tradeIssuerAddress, issuerWizardAddress), 0);
        assertEq(IERC20(yFI).allowance(tradeIssuerAddress, issuerWizardAddress), 0);
    }
}
