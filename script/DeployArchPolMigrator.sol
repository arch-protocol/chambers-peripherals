// Copyright 2022 Smash Works Inc.
// SPDX-License-Identifier: Apache License 2.0
pragma solidity ^0.8.17.0;

import "forge-std/Script.sol";
import { ArchPolMigrator } from "src/ArchPolMigrator.sol";

contract DeployScript is Script {
    address public constant PolygonMigrator = 0x29e7DF7b6A1B2b07b731457f499E1696c60E2C4e;
    address public constant MATIC = 0x7D1AfA7B718fb893dB30A3aBc0Cfc608AaCfeBB0;
    address public constant POL = 0x455e53CBB86018Ac2B8092FdCd39d8444aFFC3F6;

    /**
     * Deploy PolMigrator
     */
    function run() external {
        vm.createSelectFork("mainnet");
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        new ArchPolMigrator(PolygonMigrator, MATIC, POL);
        vm.stopBroadcast();
    }
}
