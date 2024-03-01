// SPDX-License-Identifier: Apache License 2.0
pragma solidity ^0.8.24;

import { Test } from "forge-std/Test.sol";
import { ArchemistGod } from "src/ArchemistGod.sol";
import { Archemist } from "src/Archemist.sol";

contract ArchemistGodTest is Test {
    /*//////////////////////////////////////////////////////////////
                               VARIABLES
    //////////////////////////////////////////////////////////////*/

    ArchemistGod public archemistGod;
    Archemist public validArchemist;

    address public admin = vm.addr(0x1);
    address public immutable USDC = 0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174;
    address public immutable AEDY = 0x027aF1E12a5869eD329bE4c05617AD528E997D5A;
    address public immutable ADDY = 0xAb1B1680f6037006e337764547fb82d17606c187;

    function setUp() public {
        vm.createSelectFork("polygon");
        vm.startPrank(admin);
        archemistGod = new ArchemistGod();
        validArchemist = archemistGod.createArchemist(ADDY, AEDY, 1000);
        vm.stopPrank();
    }
}
