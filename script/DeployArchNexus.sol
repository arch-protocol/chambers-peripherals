// Copyright 2022 Smash Works Inc.
// SPDX-License-Identifier: Apache License 2.0
pragma solidity ^0.8.17.0;

import "forge-std/Script.sol";
import { ArchNexus } from "src/ArchNexus.sol";

contract DeployArchNexus is Script {
    /**
     * Deploy ArchNexus contract and set the owner to the ARCH_SAFE
     */
    address public web3Archemist = 0xC68140cdf17566F8AD43db8487d6600196d79176;
    address public acaiArchemist = 0x2C0c8A17a58d37F0cA75cf9482307a8c6043d252;
    address public constant POLYGON_WMATIC = 0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270;

    function run() external {
        vm.createSelectFork("polygon");
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        ArchNexus archNexus = new ArchNexus(POLYGON_WMATIC);

        address archSafe = vm.envAddress("ARCH_SAFE");
        archNexus.addTarget(web3Archemist);
        archNexus.addTarget(acaiArchemist);
        archNexus.transferOwnership(archSafe);
        vm.stopBroadcast();
    }
}
