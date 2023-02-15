// Copyright 2022 Smash Works Inc.
// SPDX-License-Identifier: Apache License 2.0
pragma solidity ^0.8.17.0;

import "forge-std/Script.sol";
import {Chamber} from "chambers/Chamber.sol";
import {IChamberGod} from "chambers/interfaces/IChamberGod.sol";
import {IIssuerWizard} from "chambers/interfaces/IIssuerWizard.sol";
import {IStreamingFeeWizard} from "chambers/interfaces/IStreamingFeeWizard.sol";
import {IRebalanceWizard} from "chambers/interfaces/IRebalanceWizard.sol";
import {IVault} from "src/interfaces/IVault.sol";

contract CreateUSHY is Script {
    /**
     * Create list of wizards, managers, constituents, quantities
     * Creates $USHY chamber
     */
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        address ushyOwner = vm.envAddress("USHY_OWNER_ADDRESS");
        address ushyManager = vm.envAddress("USHY_MANAGER_ADDRESS");

        IChamberGod god = IChamberGod(0x0000000000000000000000000000000000000000);
        IIssuerWizard issuerWizard = IIssuerWizard(0x0000000000000000000000000000000000000000);
        IStreamingFeeWizard streamingFeeWizard = IStreamingFeeWizard(0x0000000000000000000000000000000000000000);
        IRebalanceWizard rebalanceWizard = IRebalanceWizard(0x0000000000000000000000000000000000000000);

        address[] memory wizards = new address[](3);
        wizards[0] = address(issuerWizard);
        wizards[1] = address(streamingFeeWizard);
        wizards[2] = address(rebalanceWizard);

        address[] memory managers = new address[](2);
        managers[0] = ushyOwner;
        managers[1] = ushyManager;

        address yvUSDC = 0xa354F35829Ae975e850e23e9615b11Da1B3dC4DE;
        address yvUSDT = 0x3B27F92C0e212C671EA351827EDF93DB27cc0c65;
        address yvDAI = 0xdA816459F1AB5631232FE5e97a05BBBb94970c95;

        address[] memory constituents = new address[](3);
        constituents[0] = yvUSDC; // yvUSDC
        constituents[1] = yvUSDT; // yvUSDT
        constituents[2] = yvDAI; // yvDAI

        uint256[] memory quantities = new uint256[](3);
        quantities[0] = 10e18 / (3 * IVault(yvUSDC).pricePerShare()); // 10e18 / (3 * pricePerShare * 1 USD)
        quantities[1] = 10e18 / (3 * IVault(yvUSDT).pricePerShare()); 
        quantities[2] = 10e18 / (3 * IVault(yvDAI).pricePerShare());

        address chamber = god.createChamber("Arch Stable Dollar Yield", "SDY", constituents, quantities, wizards, managers);
        Chamber(chamber).transferOwnership(ushyOwner);
        
        vm.stopBroadcast();
    }
}
