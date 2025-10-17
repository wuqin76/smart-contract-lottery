// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {HelperConfig, CodeConstants} from "./HelperConfig.s.sol";
import {VRFCoordinatorV2_5Mock} from "lib/chainlink-brownie-contracts/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {console} from "lib/forge-std/src/console.sol";
import {LinkToken} from "test/mocks/LinkToken.sol";
import {DevOpsTools} from "lib/foundry-devops/src/DevOpsTools.sol";

contract CreateSubscription is Script, CodeConstants {
    function createSubscriptionUsingConfig() public returns (uint256, address) {
        HelperConfig helperConfig = new HelperConfig();
        address vrfCoordinator = helperConfig.getConfig().vrfCoordinator;
        address account = helperConfig.getConfig().account;
        (uint256 subId, ) = createSubscriptions(vrfCoordinator, account);
        return (subId, vrfCoordinator);
    }

    function createSubscriptions(
        address vrfCoordinator,
        address account
    ) public returns (uint256, address) {
        console.log("creating subscription on chainid:", block.chainid);
        vm.startBroadcast(account);
        uint256 subId = VRFCoordinatorV2_5Mock(vrfCoordinator)
            .createSubscription(); //createSubscription是VRFCoordinatorV2_5Mock合约中的函数，作用是创建一个新的订阅，并返回订阅ID
        vm.stopBroadcast();

        console.log("subscription created with id:", subId);
        console.log("please update the subscriptionId in HelperConfig.s.sol");
        return (subId, vrfCoordinator);
    }

    function run() public {
        createSubscriptionUsingConfig();
    }
}

contract AddConsumer is Script {
    function addConsumerUsingConfig(address mostRencentlyDeployed) public {
        HelperConfig helperConfig = new HelperConfig();
        address vrfCoordinator = helperConfig.getConfig().vrfCoordinator;
        uint256 subscriptionId = helperConfig.getConfig().subscriptionId;
        address account = helperConfig.getConfig().account;
        addConsumer(
            mostRencentlyDeployed,
            vrfCoordinator,
            subscriptionId,
            account
        );
    }

    function addConsumer(
        address contractToAddtoVrf,
        address vrfCoordinator,
        uint256 subscriptionId,
        address account
    ) public {
        console.log("Add consumer to subscription on chainid:", block.chainid);
        console.log("Using vrfCoordinator:", vrfCoordinator);
        console.log("Using subscriptionId:", subscriptionId);
        vm.startBroadcast(account);
        VRFCoordinatorV2_5Mock(vrfCoordinator).addConsumer(
            subscriptionId,
            contractToAddtoVrf
        );
        console.log("Consumer added:", contractToAddtoVrf);
        vm.stopBroadcast();
    }

    function run() public {
        address mostRencentlyDeployed = DevOpsTools.get_most_recent_deployment(
            "Raffle",
            block.chainid
        );
        addConsumerUsingConfig(mostRencentlyDeployed);
    }
}

contract FundSubscription is Script, CodeConstants {
    uint256 constant FUND_AMOUNT = 10 ether; // 提高充值金额以支付 VRF 费用

    function fundSubscriptionUsingConfig() public {
        HelperConfig helperConfig = new HelperConfig();
        address vrfCoordinator = helperConfig.getConfig().vrfCoordinator;
        uint256 subscriptionId = helperConfig.getConfig().subscriptionId;
        address linkToken = helperConfig.getConfig().link;
        address account = helperConfig.getConfig().account;
        fundSubscription(vrfCoordinator, subscriptionId, linkToken, account);
    }

    function fundSubscription(
        address vrfCoordinator,
        uint256 subscriptionId,
        address linkToken,
        address account
    ) public {
        console.log("Funding subscription on chainid:", block.chainid);
        console.log("Using vrfCoordinator:", vrfCoordinator);
        console.log("Using link token:", linkToken);
        if (block.chainid == CodeConstants.LOCAL_CHAIN_ID) {
            vm.startBroadcast();
            VRFCoordinatorV2_5Mock(vrfCoordinator).fundSubscriptionWithNative{
                value: FUND_AMOUNT
            }(subscriptionId);
            vm.stopBroadcast();
        } else {
            vm.startBroadcast(account);
            LinkToken(linkToken).transferAndCall(
                vrfCoordinator,
                FUND_AMOUNT,
                abi.encode(subscriptionId)
            );
            console.log(
                "Funded subscription:",
                subscriptionId,
                "with link token:",
                linkToken
            );
            vm.stopBroadcast();
        }
    }

    function run() public {
        fundSubscriptionUsingConfig();
    }
}

/*不能完全自动的原因
CreateSubscription

真实网络上的 VRFCoordinator 不允许任何地址直接用合约脚本创建订阅（通常要在 Chainlink VRF 官方网站UI上手动操作，登录钱包创建订阅），返回 subId。
你必须手动创建，拿到 subId，然后再填到 HelperConfig 或脚本参数里。
FundSubscription

可以自动化（脚本实现），用 LINK 的 transferAndCall 方法给 VRFCoordinator充值（需要你的钱包里有LINK余额）。
这个步骤可以脚本自动完成，但前提是你已经有 subId。
AddConsumer

可以部分自动化：如果 VRFCoordinator合约公开 addConsumer 方法，你可以用脚本（如上）调用它，把 raffle 合约地址加到 consumers 列表。
但有时候（比如 UI设置/权限限制），需要你手动去 Chainlink VRF 网站添加 consumer。
一些链（如主网或部分测试网）可能有权限/时间延迟/多签等限制，导致不能完全自动化。
总结：实际测试网/主网，只有“注资”和“添加消费者”可以部分自动化，创建订阅必须手动（拿subId填到脚本/配置）。*/
