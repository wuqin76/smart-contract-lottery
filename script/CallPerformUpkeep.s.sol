// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {Raffle} from "../src/Raffle.sol";

contract CallPerformUpkeep is Script {
    function run() external {
        // 从最新部署中获取合约地址（您需要替换为实际地址）
        address raffleAddress = vm.envOr("RAFFLE_ADDRESS", address(0));

        if (raffleAddress == address(0)) {
            console2.log("Please set RAFFLE_ADDRESS environment variable");
            console2.log("Example: export RAFFLE_ADDRESS=0xa194...f3c4");
            revert("RAFFLE_ADDRESS not set");
        }

        Raffle raffle = Raffle(payable(raffleAddress));

        // 首先检查是否需要 upkeep
        (bool upkeepNeeded, ) = raffle.checkUpkeep("");
        console2.log("Upkeep needed:", upkeepNeeded);

        if (!upkeepNeeded) {
            console2.log("Upkeep not needed. Check conditions:");
            console2.log("- Balance:", address(raffle).balance);
            console2.log("- Players:", raffle.getNumberOfPlayers());
            console2.log("- State:", uint256(raffle.getRaffleState()));
            return;
        }

        vm.startBroadcast();

        // 调用 performUpkeep
        raffle.performUpkeep("");

        vm.stopBroadcast();

        console2.log("performUpkeep called successfully!");
    }
}
