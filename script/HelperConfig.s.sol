// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {VRFCoordinatorV2_5Mock} from "lib/chainlink-brownie-contracts/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol"; //导入VRFCoordinatorV2_5Mock合约
import {LinkToken} from "test/mocks/LinkToken.sol";

abstract contract CodeConstants {
    //存储常量
    //VRF MOCK值 - 调整为更低的费用以适应测试
    uint96 public constant MOCK_base_fee = 0.1 ether; // 基础费用降低到 0.1 ether
    uint96 public constant MOCK_gas_price = 1; // gas 价格设为 1 wei (极低)
    int256 public constant MOCK_wei_per_unit_link = 4e15; // 1 LINK = 0.004 ETH

    uint256 public constant ETH_SEPOLIA_CHAIN_ID = 11155111;
    uint256 public constant LOCAL_CHAIN_ID = 31337;
    uint256 public constant MAINNET_CHAIN_ID = 1;
}
error HelperConfig_InvalidChainID();

contract HelperConfig is CodeConstants, Script {
    struct NetworkConfig {
        uint256 entranceFee;
        uint256 interval;
        address vrfCoordinator;
        bytes32 keyHash;
        uint256 subscriptionId;
        uint32 callbackGasLimit;
        address link; //可选的Link代币地址
        address account; //可选的部署合约的账户地址
    }

    NetworkConfig public localNetworkConfig;

    mapping(uint256 chainId => NetworkConfig) public networkConfigs;

    constructor() {
        networkConfigs[ETH_SEPOLIA_CHAIN_ID] = getSepoliaEthConfig();
        networkConfigs[MAINNET_CHAIN_ID] = getMainnetEthConfig();
    }

    function getByConfigChainId(
        uint256 chainId
    ) public returns (NetworkConfig memory) {
        //作用: 根据chainId获取对应的配置
        if (networkConfigs[chainId].vrfCoordinator != address(0)) {
            //当前chainId有配置
            return networkConfigs[chainId];
        } else if (chainId == LOCAL_CHAIN_ID) {
            return getLocalEthConfig();
        } else {
            revert HelperConfig_InvalidChainID();
        }
    }

    function getConfig() public returns (NetworkConfig memory) {
        //作用: 获取当前网络的配置
        return getByConfigChainId(block.chainid);
    }

    function getSepoliaEthConfig() public pure returns (NetworkConfig memory) {
        return
            NetworkConfig({
                entranceFee: 0.01 ether,
                vrfCoordinator: 0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B,
                interval: 30,
                keyHash: 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae, // 150 gwei Key Hash
                callbackGasLimit: 500000,
                subscriptionId: 52412282273480575950014274317797612201312574112631470711229366394913322530300,
                link: 0x779877A7B0D9E8603169DdbD7836e478b4624789,
                account: 0x6DDee759E936b0d705c4997EC9972e307A1452B5
            });
    }

    function getMainnetEthConfig() public pure returns (NetworkConfig memory) {
        return
            NetworkConfig({
                entranceFee: 0.01 ether,
                vrfCoordinator: 0xd691f04bc0C9a24Edb78af9E005Cf85768F694C9, // 替换为实际的Mainnet VRF Coordinator地址
                interval: 300, // 5分钟
                keyHash: 0x130dba50ad435d4ecc214aad0d5820474137bd68e7e77724144f27c3c377d3d4, // 替换为实际的Mainnet Key Hash
                callbackGasLimit: 500000,
                subscriptionId: 0, // 替换为实际的Mainnet订阅ID
                link: 0x514910771AF9Ca656af840dff83E8264EcF986CA, // Mainnet LINK代币地址
                account: 0x6DDee759E936b0d705c4997EC9972e307A1452B5
            });
    }

    function getLocalEthConfig() public returns (NetworkConfig memory) {
        if (localNetworkConfig.vrfCoordinator != address(0)) {
            return localNetworkConfig;
        }

        vm.startBroadcast();
        VRFCoordinatorV2_5Mock vrfCoordinator = new VRFCoordinatorV2_5Mock(
            MOCK_base_fee,
            MOCK_gas_price,
            MOCK_wei_per_unit_link
        );
        LinkToken linkToken = new LinkToken();
        vm.stopBroadcast();

        localNetworkConfig = NetworkConfig({
            entranceFee: 0.01 ether,
            vrfCoordinator: address(vrfCoordinator),
            interval: 60,
            keyHash: 0x8077df514608a09f83e4e8d300645594e5d7234665448ba83f51a50f842bd3d9, //随便写一个KeyHash都能被MOCK模拟工作，
            callbackGasLimit: 500000, //MOCK里面不重要，随便写
            subscriptionId: 0,
            link: address(linkToken), //本地不需要Link代币
            account: msg.sender //本地部署合约的账户地址
        });
        return localNetworkConfig;
    }
}
