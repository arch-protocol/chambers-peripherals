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
    address public baseToken = 0x3c499c542cEF5E3811e1192ce70d8cC03d5c3359; // USDC from circle.
    address public exchangeToken = 0x9F5C845A178dFCB9Abe1e9D3649269826ce43901; // ACAI
    uint24 public fee = 50;
    address public backendOperator = 0xf33F0262dD37c9ae09393d09764aa363dcdC9627; // DEV Backend Operator

    function run() external {
        vm.createSelectFork("polygon");
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        Archemist archemist = archemistGod.createArchemist(exchangeToken, baseToken, fee);

        address archSafe = vm.envAddress("ARCH_SAFE");

        archemist.addOperator(backendOperator);
        archemist.addAdmin(archSafe);
        vm.stopBroadcast();
    }
}
