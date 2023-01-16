// Copyright 2022 Smash Works Inc.
// SPDX-License-Identifier: Apache License 2.0
pragma solidity ^0.8.17.0;

import {ChamberTestUtils} from "test/utils/ChamberTestUtils.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ExposedTradeIssuer} from "test/utils/ExposedTradeIssuer.sol";

contract TradeIssuerIntegrationInternalSellAssetsForTokenInDexTest is ChamberTestUtils {
    /*//////////////////////////////////////////////////////////////
                              VARIABLES
    //////////////////////////////////////////////////////////////*/

    ExposedTradeIssuer public tradeIssuer;
    address public tradeIssuerAddress;
    address payable public zeroExProxy = payable(0xDef1C0ded9bec7F1a1670819833240f027b25EfF); // 0x on ETH
    address public dAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    address public yFI = 0x0bc529c00C6401aEF6D220BE8C6Ea1667F6Ad93e; // YFI on ETH
    address public wETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    bytes[] public quotes = new bytes[](2);
    address[] public components = new address[](2);
    uint256[] public componentsQuantities = new uint256[](2);

    /*//////////////////////////////////////////////////////////////
                              SET UP
    //////////////////////////////////////////////////////////////*/

    function setUp() public {
        tradeIssuer = new ExposedTradeIssuer(zeroExProxy, wETH);
        tradeIssuerAddress = address(tradeIssuer);
        vm.label(tradeIssuerAddress, "TradeIssuer");
        vm.label(dAI, "DAI");
        vm.label(yFI, "YFI");
        components[0] = dAI;
        components[1] = yFI;
    }

    /*//////////////////////////////////////////////////////////////
                              REVERT
    //////////////////////////////////////////////////////////////*/

    /**
     * [REVERT] Cannot sell assets if trader does not have enough balance of an asset
     * to execute the quote made with more balance.
     */
    function testCannotSellAssetsForTokenInDexIfNotEnoughBalance(
        uint64 sellAmount0,
        uint64 sellAmount1
    ) public {
        vm.assume(sellAmount0 > (1 ether));
        vm.assume(sellAmount0 < (1000000 ether));
        vm.assume(sellAmount1 > (1 ether));
        vm.assume(sellAmount1 < (100 ether));

        componentsQuantities[0] = sellAmount0;
        componentsQuantities[1] = sellAmount1;

        // Get quotes. 'buyAmount' is not precise, so we skip it
        (bytes memory quote0,) = getQuoteDataForRedeem(sellAmount0, components[0], wETH);
        (bytes memory quote1,) = getQuoteDataForRedeem(sellAmount1, components[1], wETH);

        quotes[0] = quote0;
        quotes[1] = quote1;

        // No Balance Sent

        vm.expectRevert(); // Custom error from proxy
        // Call
        tradeIssuer.sellAssetsForTokenInDex(
            quotes, IERC20(wETH), components, componentsQuantities, 5
        );

        // Nothing was sold
        assertEq(IERC20(components[0]).balanceOf(tradeIssuerAddress), 0);
        assertEq(IERC20(components[1]).balanceOf(tradeIssuerAddress), 0);

        // No WETH received
        assertEq(IERC20(wETH).balanceOf(tradeIssuerAddress), 0);
    }

    /**
     * [REVERT] Cannot sell assets if trader uses a quote that sells less than the slippage
     * allowed. i.e A token is undersold in dex.
     */
    function testCannotSellAssetsForTokenInDexIfUndersoldAsset(
        uint64 sellAmount0,
        uint64 sellAmount1
    ) public {
        vm.assume(sellAmount0 > (1 ether));
        vm.assume(sellAmount0 < (1000000 ether));
        vm.assume(sellAmount1 > (1 ether));
        vm.assume(sellAmount1 < (100 ether));

        componentsQuantities[0] = sellAmount0;
        componentsQuantities[1] = sellAmount1;

        // Get quotes. 'buyAmount' is not precise, so we skip it
        (bytes memory quote0,) = getQuoteDataForRedeem(sellAmount0 / 2, components[0], wETH); // Quote with half the amount
        (bytes memory quote1,) = getQuoteDataForRedeem(sellAmount1, components[1], wETH);

        quotes[0] = quote0;
        quotes[1] = quote1;

        // Send balance
        deal(dAI, tradeIssuerAddress, sellAmount0);
        deal(yFI, tradeIssuerAddress, sellAmount1);

        // Call
        vm.expectRevert("Undersold dex asset");
        tradeIssuer.sellAssetsForTokenInDex(
            quotes, IERC20(wETH), components, componentsQuantities, 5
        );

        // Nothing was sold
        assertEq(IERC20(components[0]).balanceOf(tradeIssuerAddress), sellAmount0);
        assertLe(IERC20(components[1]).balanceOf(tradeIssuerAddress), sellAmount1);

        // I received what the functions says I received
        assertEq(IERC20(wETH).balanceOf(tradeIssuerAddress), 0);
    }

    /**
     * [REVERT] Cannot sell assets if a quote is malformed.
     */
    function testCannotSellAssetsForTokenInDexWithMalformedQuote(
        uint64 sellAmount0,
        uint64 sellAmount1
    ) public {
        vm.assume(sellAmount0 > (1 ether));
        vm.assume(sellAmount0 < (1000000 ether));
        vm.assume(sellAmount1 > (1 ether));
        vm.assume(sellAmount1 < (100 ether));

        componentsQuantities[0] = sellAmount0;
        componentsQuantities[1] = sellAmount1;

        // Get quotes. 'buyAmount' is not precise, so we skip it

        (bytes memory quote1,) = getQuoteDataForRedeem(sellAmount1, components[1], wETH);

        quotes[0] = bytes("BAD_DEX_QUOTE");
        quotes[1] = quote1;

        // Send balance
        deal(dAI, tradeIssuerAddress, sellAmount0);
        deal(yFI, tradeIssuerAddress, sellAmount1);

        // Call
        vm.expectRevert(); // Custom error from proxy
        tradeIssuer.sellAssetsForTokenInDex(
            quotes, IERC20(wETH), components, componentsQuantities, 5
        );

        // Nothing was sold
        assertEq(IERC20(components[0]).balanceOf(tradeIssuerAddress), sellAmount0);
        assertEq(IERC20(components[1]).balanceOf(tradeIssuerAddress), sellAmount1);

        // No WETH received
        assertEq(IERC20(wETH).balanceOf(tradeIssuerAddress), 0);
    }

    /*//////////////////////////////////////////////////////////////
                              SUCCESS
    //////////////////////////////////////////////////////////////*/

    /**
     * [SUCCESS] Should skip the swap if a component is the outputToken
     */
    function testSellAssetsForTokenInDexWithAConstituentBeingTheOutputToken(
        uint64 sellAmount0,
        uint64 sellAmount1
    ) public {
        vm.assume(sellAmount0 > (1 ether));
        vm.assume(sellAmount0 < (1000000 ether));
        vm.assume(sellAmount1 > (1 ether));
        vm.assume(sellAmount1 < (100 ether));

        components[0] = wETH;
        componentsQuantities[0] = sellAmount0;
        componentsQuantities[1] = sellAmount1;

        uint256 component1BalanceBefore = IERC20(components[1]).balanceOf(tradeIssuerAddress);

        // Get quotes. 'buyAmount' is not precise, so we skip it. No quote zero since is the same as output token
        (bytes memory quote1,) = getQuoteDataForRedeem(sellAmount1, components[1], wETH);

        quotes[0] = bytes("Empty_Quote");
        quotes[1] = quote1;

        // Send balance
        deal(wETH, tradeIssuerAddress, sellAmount0);
        deal(yFI, tradeIssuerAddress, sellAmount1);

        // Call
        uint256 outputTokensReceived = tradeIssuer.sellAssetsForTokenInDex(
            quotes, IERC20(wETH), components, componentsQuantities, 5
        );

        assertLe(
            IERC20(components[1]).balanceOf(tradeIssuerAddress) - component1BalanceBefore,
            (componentsQuantities[1] * 5) / 1000
        );

        // I received what the functions says I received
        assertEq(IERC20(wETH).balanceOf(tradeIssuerAddress), outputTokensReceived);
    }

    /**
     * [SUCCESS] Should swap DAI and YFI for WETH. Using 0.5% slippage on the downside.
     * DAI up to 1M USD, YFI up to 700k USD 2022 prices
     */
    function testSellAssetsForTokenInDexWithTwoComponents(uint64 sellAmount0, uint64 sellAmount1)
        public
    {
        vm.assume(sellAmount0 > (1 ether));
        vm.assume(sellAmount0 < (1000000 ether));
        vm.assume(sellAmount1 > (1 ether));
        vm.assume(sellAmount1 < (100 ether));

        componentsQuantities[0] = sellAmount0;
        componentsQuantities[1] = sellAmount1;

        uint256 component0BalanceBefore = IERC20(components[0]).balanceOf(tradeIssuerAddress);
        uint256 component1BalanceBefore = IERC20(components[1]).balanceOf(tradeIssuerAddress);

        // Get quotes. 'buyAmount' is not precise, so we skip it
        (bytes memory quote0,) = getQuoteDataForRedeem(sellAmount0, components[0], wETH);
        (bytes memory quote1,) = getQuoteDataForRedeem(sellAmount1, components[1], wETH);

        quotes[0] = quote0;
        quotes[1] = quote1;

        // Send balance
        deal(dAI, tradeIssuerAddress, sellAmount0);
        deal(yFI, tradeIssuerAddress, sellAmount1);

        uint256 outputTokenBalanceBefore = IERC20(wETH).balanceOf(tradeIssuerAddress);

        // Call
        uint256 outputTokensReceived = tradeIssuer.sellAssetsForTokenInDex(
            quotes, IERC20(wETH), components, componentsQuantities, 5
        );

        // Everything was sold
        assertLe(
            IERC20(components[0]).balanceOf(tradeIssuerAddress) - component0BalanceBefore,
            (componentsQuantities[0] * 5) / 1000
        );
        assertLe(
            IERC20(components[1]).balanceOf(tradeIssuerAddress) - component1BalanceBefore,
            (componentsQuantities[1] * 5) / 1000
        );

        // I received what the functions says I received
        assertEq(
            IERC20(wETH).balanceOf(tradeIssuerAddress) - outputTokenBalanceBefore,
            outputTokensReceived
        );
    }
}
