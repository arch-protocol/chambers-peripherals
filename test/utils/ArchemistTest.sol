// SPDX-License-Identifier: Apache License 2.0
pragma solidity ^0.8.24;

import { Archemist } from "src/Archemist.sol";
import { Test } from "forge-std/Test.sol";

contract ArchemistTest is Test {
    /*//////////////////////////////////////////////////////////////
                              VARIABLES
    //////////////////////////////////////////////////////////////*/

    Archemist public archemist;

    address public admin = vm.addr(0x1);
    address public archemistGod = vm.addr(0x4);
    address public immutable USDC = 0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174;
    address public immutable AEDY = 0x027aF1E12a5869eD329bE4c05617AD528E997D5A;

    uint24 public exchangeFee = 1000;

    /*//////////////////////////////////////////////////////////////
                              SET UP
    //////////////////////////////////////////////////////////////*/

    function setUp() public {
        vm.createSelectFork("polygon");
        vm.startPrank(admin);
        archemist = new Archemist(AEDY, USDC, archemistGod, exchangeFee);
        vm.stopPrank();
    }
}
