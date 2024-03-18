// Copyright 2022 Smash Works Inc.
// SPDX-License-Identifier: Apache License 2.0
pragma solidity ^0.8.17.0;

import "forge-std/Script.sol";
import { ArchemistGod } from "src/ArchemistGod.sol";

contract DeployArchemistGod is Script {

    /**
     * Deploy ArchemistGod
    */

    address SKELLI = 0x38133FAfB7CAaEf2aC7e8BEa0CbDf01723b657A3;

    function run() external {
        vm.createSelectFork("polygon");
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        ArchemistGod archemistGod = new ArchemistGod();


        address archSafe = vm.envAddress("ARCH_SAFE");
        archemistGod.grantRole(archemistGod.MANAGER(), SKELLI);
        archemistGod.grantRole(archemistGod.DEFAULT_ADMIN_ROLE(), archSafe);
        vm.stopBroadcast();
    }
}
