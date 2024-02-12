// Copyright 2022 Smash Works Inc.
// SPDX-License-Identifier: Apache License 2.0
pragma solidity ^0.8.17.0;

import "forge-std/Script.sol";
import { TradeIssuerV3 } from "src/TradeIssuerV3.sol";

contract DeployScript is Script {
    address public constant ETH_WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address public constant ETH_CHAMBER_GOD = 0x0C9Aa1e4B4E39DA01b7459607995368E4C38cFEF;
    address public constant ETH_UNISWAP_ROUTER = 0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45;
    address public constant ETH_ZERO_EX = 0xDef1C0ded9bec7F1a1670819833240f027b25EfF;

    /**
     * Deploy TradeIssuerV3
     */
    function run() external {
        vm.createSelectFork("mainnet");
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        TradeIssuerV3 tradeIssuer = new TradeIssuerV3(ETH_WETH, ETH_CHAMBER_GOD);

        tradeIssuer.addTarget(ETH_UNISWAP_ROUTER);
        tradeIssuer.addTarget(ETH_ZERO_EX);

        address archSafe = vm.envAddress("ARCH_SAFE_ETH");
        tradeIssuer.transferOwnership(archSafe);

        vm.stopBroadcast();
    }
}
