// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17.0;

import "forge-std/StdJson.sol";
import { Test } from "forge-std/Test.sol";
import { ERC20 } from "solmate/tokens/ERC20.sol";
import { IERC20 } from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import { ITradeIssuerV3 } from "src/interfaces/ITradeIssuerV3.sol";
import { TradeIssuerV3 } from "src/TradeIssuerV3.sol";
import { ArchUtils } from "test/utils/ArchUtils.sol";
import { IChamber } from "chambers/interfaces/IChamber.sol";
import { IIssuerWizard } from "chambers/interfaces/IIssuerWizard.sol";
import { console } from "forge-std/console.sol";

contract GaslessTest is Test, ArchUtils {
    /*//////////////////////////////////////////////////////////////
                              VARIABLES
    //////////////////////////////////////////////////////////////*/
    using SafeERC20 for IERC20;
    using stdJson for string;

    string root;
    string path;
    string json;

    /*//////////////////////////////////////////////////////////////
                              SET UP
    //////////////////////////////////////////////////////////////*/
    function setUp() public {
        addLabbels();
        root = vm.projectRoot();
    }

    /*//////////////////////////////////////////////////////////////
                              AUX FUNCT
    //////////////////////////////////////////////////////////////*/

    /**
     * Redeem and Mint a chamber with trade issuer
     */
    function redeemAndMintChamber(
        uint256 chainId,
        uint256 blockNumber,
        address fromToken,
        uint256 fromTokenAmount,
        address toToken,
        uint256 toTokenAmount,
        address issuerWizard,
        ITradeIssuerV3.ContractCallInstruction[] memory contractCallInstructions
    ) public {
        // TradeIssuerV3 tradeIssuer;
        if (chainId == POLYGON_CHAIN_ID) {
            vm.createSelectFork("polygon", blockNumber);
            // tradeIssuer = deployTradeIssuerV3(chainId);
        }
        if (chainId == ETH_CHAIN_ID) {
            vm.createSelectFork("ethereum", blockNumber);
            // tradeIssuer = deployTradeIssuerV3(chainId);
        }

        ITradeIssuerV3 tradeIssuer = ITradeIssuerV3(address(POLYGON_TRADE_ISSUER_V3));

        address[] memory constituents = IChamber(fromToken).getConstituentsAddresses();

        vm.prank(ALICE);
        IERC20(fromToken).approve(address(tradeIssuer), type(uint256).max);

        deal(fromToken, ALICE, fromTokenAmount);

        uint256 previousFromTokenBalance = IERC20(fromToken).balanceOf(ALICE);
        uint256 previousToTokenBalance = IERC20(toToken).balanceOf(ALICE);

        vm.prank(ALICE);
        tradeIssuer.redeemAndMint(
            IChamber(fromToken),
            fromTokenAmount,
            IChamber(toToken),
            toTokenAmount,
            IIssuerWizard(issuerWizard),
            contractCallInstructions
        );

        uint256[] memory remanentConstituentsAmounts = new uint256[](constituents.length);

        for (uint256 i = 0; i < constituents.length; i++) {
            remanentConstituentsAmounts[i] = IERC20(constituents[i]).balanceOf(address(tradeIssuer));
            console.log(constituents[i]);
            console.log(remanentConstituentsAmounts[i]);
        }

        assertEq(previousFromTokenBalance - IERC20(fromToken).balanceOf(ALICE), fromTokenAmount);
        assertEq(IERC20(toToken).balanceOf(ALICE) - previousToTokenBalance, toTokenAmount);
    }

    /**
     * Loads params and call instructions (quote) from a local json file, and then
     * runs it to redeem mint a chamber
     */
    function runLocalRedeemAndMintQuoteTest(string memory fileName) public {
        path = string.concat(root, fileName);
        json = vm.readFile(path);
        (
            uint256 chainId,
            uint256 blockNumber,
            address fromToken,
            uint256 fromTokenAmount,
            address toToken,
            uint256 toTokenAmount,
            address issuerWizard,
            ITradeIssuerV3.ContractCallInstruction[] memory contractCallInstructions
        ) = parseRedeemAndMintQuoteFromJson(json);
        redeemAndMintChamber(
            chainId,
            blockNumber,
            fromToken,
            fromTokenAmount,
            toToken,
            toTokenAmount,
            issuerWizard,
            contractCallInstructions
        );
    }

    /**
     * Used to create json files, fetches a quote from arch and prints a JSON-readable
     * quote in console, ready to be saved for new tests. The fork is needed to get the
     * block number alongside the quote.
     */
    function printQuoteToCreateATest() public {
        vm.createSelectFork("polygon");
        fetchRedeemAndMintQuote(POLYGON_CHAIN_ID, POLYGON_AAGG, 50e18, POLYGON_AMOD);
    }

    /*//////////////////////////////////////////////////////////////
                              SUCCESS
    //////////////////////////////////////////////////////////////*/

    /**
     * [SUCCESS] Should redeem AAGG and mint ABAL
     */
    function testRedeemAndMintFromAaggToAbal() public {
        runLocalRedeemAndMintQuoteTest("/data/redeemAndMint/testRedeemAndMintFromAaggToAbal.json");
    }

    /**
     * [SUCCESS] Should redeem AAGG and mint ABAL
     */
    function testRedeemAndMintFromAaggToAmod() public {
        runLocalRedeemAndMintQuoteTest("/data/redeemAndMint/testRedeemAndMintFromAaggToAmod.json");
    }

    /**
     * [SUCCESS] Should redeem ABAL and mint AAGG
     */
    function testRedeemAndMintFromAbalToAagg() public {
        runLocalRedeemAndMintQuoteTest("/data/redeemAndMint/testRedeemAndMintFromAbalToAagg.json");
    }

    /**
     * [SUCCESS] Should redeem ABAL and mint AMOD
     */
    function testRedeemAndMintFromAbalToAmod() public {
        runLocalRedeemAndMintQuoteTest("/data/redeemAndMint/testRedeemAndMintFromAbalToAmod.json");
    }

    /**
     * [SUCCESS] Should redeem AMOD and mint AAGG
     */
    function testRedeemAndMintFromAmodToAagg() public {
        runLocalRedeemAndMintQuoteTest("/data/redeemAndMint/testRedeemAndMintFromAmodToAagg.json");
    }

    /**
     * [SUCCESS] Should redeem AMOD and mint ABAL
     */
    function testRedeemAndMintFromAmodToAbal() public {
        runLocalRedeemAndMintQuoteTest("/data/redeemAndMint/testRedeemAndMintFromAmodToAbal.json");
    }
}
