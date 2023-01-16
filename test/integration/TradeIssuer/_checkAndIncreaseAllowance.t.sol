// Copyright 2022 Smash Works Inc.
// SPDX-License-Identifier: Apache License 2.0
pragma solidity ^0.8.17.0;

import "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ExposedTradeIssuer} from "test/utils/ExposedTradeIssuer.sol";
import {Chamber} from "chambers/Chamber.sol";
import {ChamberFactory} from "test/utils/Factories.sol";
import {PreciseUnitMath} from "chambers/lib/PreciseUnitMath.sol";

contract TradeIssuerIntegrationIngernalCheckAndIncreaseAllowanceTest is Test {
    using SafeERC20 for IERC20;
    using PreciseUnitMath for uint256;

    /*//////////////////////////////////////////////////////////////
                              VARIABLES
    //////////////////////////////////////////////////////////////*/
    ExposedTradeIssuer public tradeIssuer;
    ChamberFactory public chamberFactory;
    Chamber public chamber;
    address payable public dexAgg = payable(address(0x1));
    address public chamberAddress;
    address public issuerWizardAddress;
    address public tradeIssuerAddress;
    address public chamberGodAddress = vm.addr(0x791782394);
    address public dAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F; // dAI on ETH
    address public yFI = 0x0bc529c00C6401aEF6D220BE8C6Ea1667F6Ad93e; // YFI on ETH
    address public wETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2; // WETH on ETH
    address public inputToken = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48; // USDC on ETH
    address[] public constituents = new address[](2);
    uint256[] public constituentsQuantities = new uint256[](2);

    /*//////////////////////////////////////////////////////////////
                              SET UP
    //////////////////////////////////////////////////////////////*/

    function setUp() public {
        tradeIssuer = new ExposedTradeIssuer(dexAgg, wETH);

        tradeIssuerAddress = address(tradeIssuer);
        vm.label(tradeIssuerAddress, "TradeIssuer");
        constituents[0] = dAI;
        constituents[1] = yFI;

        address[] memory wizards = new address[](1);
        address[] memory managers = new address[](0);

        wizards[0] = issuerWizardAddress;

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
     * [REVERT] Should revert when required amount is zero
     */
    function testCannotCheckAndIncreaseAllowanceWhenRequiredAmountIsZero() public {
        vm.expectRevert(bytes("Required amount cannot be zero"));
        tradeIssuer.checkAndIncreaseAllowance(dAI, dexAgg, 0);
    }

    /*//////////////////////////////////////////////////////////////
                              SUCCESS
    //////////////////////////////////////////////////////////////*/

    /**
     * [SUCCESS] Should check allowance and increase it to max. when current allowance is zero
     */
    function testCheckAndIncreaseAllowanceShouldIncreaseToMaxWhenIsZero(uint256 requiredAmount)
        public
    {
        vm.assume(requiredAmount > 0);
        vm.assume(requiredAmount < type(uint256).max);
        vm.expectCall(dAI, abi.encodeCall(IERC20(dAI).allowance, (tradeIssuerAddress, dexAgg)));
        vm.expectCall(dAI, abi.encodeCall(IERC20(dAI).approve, (dexAgg, type(uint256).max)));
        tradeIssuer.checkAndIncreaseAllowance(dAI, dexAgg, requiredAmount);

        assertEq(IERC20(dAI).allowance(address(tradeIssuer), dexAgg), type(uint256).max);
    }

    /**
     * [SUCCESS] Should check allowance and increase it to max. when current allowance is less
     * than required amount
     */
    function testCheckAndIncreaseAllowanceShouldIncreaseToMaxWhenIsNotEnough(uint256 someAmount)
        public
    {
        vm.assume(someAmount > 0);
        vm.assume(someAmount < type(uint256).max);
        vm.prank(address(tradeIssuer));
        IERC20(dAI).approve(dexAgg, someAmount);

        vm.expectCall(dAI, abi.encodeCall(IERC20(dAI).allowance, (tradeIssuerAddress, dexAgg)));
        vm.expectCall(dAI, abi.encodeCall(IERC20(dAI).approve, (dexAgg, type(uint256).max)));
        tradeIssuer.checkAndIncreaseAllowance(dAI, dexAgg, someAmount + 1);

        assertEq(IERC20(dAI).allowance(address(tradeIssuer), dexAgg), type(uint256).max);
    }

    /**
     * [SUCCESS] Should check and NOT increase allowance when its already enough.
     * //
     */
    function testCheckAndIncreaseAllowanceShouldNotIncreaseWhenItsEnoughy(uint256 requiredAmount)
        public
    {
        vm.assume(requiredAmount > 0);
        vm.assume(requiredAmount < type(uint256).max);
        vm.prank(address(tradeIssuer));
        IERC20(dAI).approve(dexAgg, requiredAmount);

        vm.expectCall(dAI, abi.encodeCall(IERC20(dAI).allowance, (tradeIssuerAddress, dexAgg)));

        tradeIssuer.checkAndIncreaseAllowance(dAI, dexAgg, requiredAmount);

        assertEq(IERC20(dAI).allowance(address(tradeIssuer), dexAgg), requiredAmount);
    }
}
