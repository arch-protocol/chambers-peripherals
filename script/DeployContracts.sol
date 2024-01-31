// Copyright 2022 Smash Works Inc.
// SPDX-License-Identifier: Apache License 2.0
pragma solidity ^0.8.17.0;

import "forge-std/Script.sol";
import { ChamberGod } from "chambers/ChamberGod.sol";
import { IssuerWizard } from "chambers/IssuerWizard.sol";
import { TradeIssuer } from "src/TradeIssuer.sol";
import { StreamingFeeWizard } from "chambers/StreamingFeeWizard.sol";
import { RebalanceWizard } from "chambers/RebalanceWizard.sol";

contract DeployContracts is Script {
    /**
     * Deploys a ChamberGod
     * Creates all Wizards
     * Adds them to ChamberGod
     * Deploy TradeIssuer
     * Transfer ownership of ChamberGod
     */
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        ChamberGod god = new ChamberGod();
        IssuerWizard issuerWizard = new IssuerWizard(address(god));
        StreamingFeeWizard streamingFeeWizard = new StreamingFeeWizard();
        RebalanceWizard rebalanceWizard = new RebalanceWizard();

        god.addWizard(address(issuerWizard));
        god.addWizard(address(streamingFeeWizard));
        god.addWizard(address(rebalanceWizard));

        // address polyEeth = 0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270;
        address weth = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
        address zeroEx = 0xDef1C0ded9bec7F1a1670819833240f027b25EfF;

        new TradeIssuer(payable(zeroEx), weth);

        address archGodAddress = vm.envAddress("GOD_OWNER_ADDRESS");
        god.transferOwnership(archGodAddress);

        vm.stopBroadcast();
    }
}
