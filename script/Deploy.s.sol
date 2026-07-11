// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {GaslessVault} from "../src/GaslessVault.sol";

contract Deploy is Script {
    function run() external {
        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));
        new GaslessVault(vm.envAddress("TOKEN"));
        vm.stopBroadcast();
    }
}
