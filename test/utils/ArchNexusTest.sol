// SPDX-License-Identifier: Apache License 2.0
pragma solidity ^0.8.24;

import { Test } from "forge-std/Test.sol";

import { Archemist } from "src/Archemist.sol";
import { ArchNexus } from "src/ArchNexus.sol";
import { ArchemistGod } from "src/ArchemistGod.sol";

contract ArchNexusTest is Test {
    /*//////////////////////////////////////////////////////////////
                              VARIABLES
    //////////////////////////////////////////////////////////////*/

    Archemist public archemist; // Base Case (AEDY, WETH)

    Archemist public archemistAedyAddy;

    Archemist public archemistAddyUsdc;

    ArchemistGod public archemistGod;

    ArchNexus public archNexus;

    address public admin = vm.addr(0x1);
    address public immutable ALICE = vm.addr(0x2);
    address public constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address public constant AEDY = 0x103bb3EBc6F61b3DB2d6e01e54eF7D9899A2E16B;
    address public constant ADDY = 0xE15A66b7B8e385CAa6F69FD0d55984B96D7263CF;
    address public constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    uint24 public exchangeFee = 1000;
    uint256 public EIGHTEEN_DECIMALS = 10 ** 18;
    uint256 public SIX_DECIMALS = 10 ** 6;

    /*//////////////////////////////////////////////////////////////
                              SET UP
    //////////////////////////////////////////////////////////////*/

    function setUp() public {
        vm.createSelectFork("ethereum", 19483754);
        vm.startPrank(admin);
        archemistGod = new ArchemistGod();
        archNexus = new ArchNexus(WETH);
        archemist = archemistGod.createArchemist(AEDY, WETH, exchangeFee);
        archemistAedyAddy = archemistGod.createArchemist(AEDY, ADDY, exchangeFee);
        archemistAddyUsdc = archemistGod.createArchemist(USDC, ADDY, exchangeFee);
        vm.stopPrank();
    }
}
