// SPDX-License-Identifier: Apache License 2.0
pragma solidity ^0.8.24;

import { Test } from "forge-std/Test.sol";

import { ArchPolMigrator } from "src/ArchPolMigrator.sol";

contract ArchPolMigratorTest is Test {
    /*//////////////////////////////////////////////////////////////
                              VARIABLES
    //////////////////////////////////////////////////////////////*/

    ArchPolMigrator public archPolMigrator;

    address public admin = vm.addr(0x1);
    address public immutable ALICE = vm.addr(0x2);
    address public constant MATIC = 0x7D1AfA7B718fb893dB30A3aBc0Cfc608AaCfeBB0;
    address public constant POL = 0x455e53CBB86018Ac2B8092FdCd39d8444aFFC3F6;
    address public constant PolygonMigrator = 0x29e7DF7b6A1B2b07b731457f499E1696c60E2C4e;

    /*//////////////////////////////////////////////////////////////
                              SET UP
    //////////////////////////////////////////////////////////////*/

    function setUp() public virtual {
        vm.createSelectFork("ethereum");
        vm.startPrank(admin);
        archPolMigrator = new ArchPolMigrator(PolygonMigrator, MATIC, POL);
        vm.stopPrank();
    }
}
