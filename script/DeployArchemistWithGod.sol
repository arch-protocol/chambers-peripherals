// Copyright 2022 Smash Works Inc.
// SPDX-License-Identifier: Apache License 2.0
pragma solidity ^0.8.17.0;

import "forge-std/Script.sol";
import { ArchemistGod } from "src/ArchemistGod.sol";
import { Archemist } from "src/Archemist.sol";

contract DeployArchemistWithGod is Script {

    /**
     * Deploy Archemist using archemistGod
    */

    address public skelli = 0x38133FAfB7CAaEf2aC7e8BEa0CbDf01723b657A3;
    ArchemistGod public archemistGod = ArchemistGod(0xE1E9568B9F735Cafb282BB164687d4c37587Bf90);
    address public baseToken = 0x3c499c542cEF5E3811e1192ce70d8cC03d5c3359;// USDC from circle.
    address public exchangeToken = 0xC4ea087fc2cB3a1D9ff86c676F03abE4F3EE906F;// WEB3 Chamber
    uint24 public fee = 5000;
    address public backendOperator = 0xf33F0262dD37c9ae09393d09764aa363dcdC9627; // DEV Backend Operator


    function run() external {
        vm.createSelectFork("polygon");
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        Archemist archemist = archemistGod.createArchemist( exchangeToken, baseToken, fee);


        address archSafe = vm.envAddress("ARCH_SAFE");

        archemist.grantRole(archemist.DEFAULT_ADMIN_ROLE(), archSafe);
        archemist.addOperator(backendOperator);
        archemist.addAdmin(archSafe);
        vm.stopBroadcast();
    }
}
