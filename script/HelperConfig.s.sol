// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Script} from "forge-std/Script.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {LinkToken} from "../test/mocks/LinkToken.sol";

abstract contract CodeConstants {
    uint96 public MOCK_BASE_FEE = 0.25 ether;
    uint96 public MOCK_GAS_PRICE_LINK = 1e9;
    // LINK / ETH price
    int256 public MOCK_WEI_PER_UINT_LINK = 4e15;

    address public FOUNDRY_DEFAULT_SENDER =
        0x1804c8AB1F12E6bbf3894d4083f33e07309d1f38;

    uint256 public constant ETH_SEPOLIA_CHAIN_ID = 11155111;
    uint256 public constant ETH_MAINNET_CHAIN_ID = 1;
    uint256 public constant LOCAL_CHAIN_ID = 31337;
}

contract HelperConfig is CodeConstants, Script {
    /** 
    // ERRORS
     */
    error HelperConfig__InvalidChainId();

    /** 
    // TYPES
     */
    struct NetworkConfig {
        uint256 entranceFee;
        uint256 interval;
        uint256 subscriptionId;
        address vrfCoordinator2_5;
        bytes32 keyHash;
        uint32 callbackGasLimit;
        address link;
        address account;
    }
    NetworkConfig public localNetworkConfig;
    mapping(uint256 chainId => NetworkConfig) public networkConfigs;

    constructor() {
        // if (block.chainid == 11155111) {
        //     activeNetworkConfig = getSepoliaEthConfig();
        // } else if (block.chainid == 1) {
        //     activeNetworkConfig = getMainnetEthConfig();
        // } else {
        //     activeNetworkConfig = getOrCreateAnvilEthConfig();
        // }

        networkConfigs[ETH_MAINNET_CHAIN_ID] = getMainnetEthConfig();
        networkConfigs[ETH_SEPOLIA_CHAIN_ID] = getSepoliaEthConfig();
    }

    function setConfig(uint256 chainId, NetworkConfig memory configs) public {
        networkConfigs[chainId] = configs;
    }

    function getConfig() public returns (NetworkConfig memory) {
        return getConfigByChainId(block.chainid);
    }

    function getConfigByChainId(
        uint256 chainId
    ) public returns (NetworkConfig memory) {
        if (networkConfigs[chainId].vrfCoordinator2_5 != address(0)) {
            return networkConfigs[chainId];
        } else if (chainId == LOCAL_CHAIN_ID) {
            return getOrCreateAnvilEthConfig();
        } else {
            revert HelperConfig__InvalidChainId();
        }
    }

    function getSepoliaEthConfig()
        public
        pure
        returns (NetworkConfig memory SepoliaNetworkConfig)
    {
        SepoliaNetworkConfig = NetworkConfig({
            entranceFee: 0.01 ether,
            interval: 30,
            subscriptionId: 0, // update with our sub id that has LINKs
            vrfCoordinator2_5: 0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B,
            keyHash: 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae,
            callbackGasLimit: 500000, // 500,000 gas
            link: 0x779877A7B0D9E8603169DdbD7836e478b4624789,
            account: 0x78fCFee041799aFb72CF26a142BC5834a21A3D4D
        });
    }

    function getMainnetEthConfig()
        public
        returns (NetworkConfig memory MainnetNetworkConfig)
    {
        MainnetNetworkConfig = NetworkConfig({
            entranceFee: 0.01 ether,
            interval: 30,
            subscriptionId: 0, // If left as 0, our scripts will create one
            vrfCoordinator2_5: 0x271682DEB8C4E0901D1a1550aD2e64D568E69909,
            keyHash: 0x9fe0eebf5e446e3c998ec9bb19951541aee00bb90ea201ae456421a2ded86805,
            callbackGasLimit: 500000, // 500,000 gas
            link: 0x514910771AF9Ca656af840dff83E8264EcF986CA,
            account: 0x78fCFee041799aFb72CF26a142BC5834a21A3D4D

            // subscriptionId: 0, // If left as 0, our scripts will create one!
            // keyHash: 0x9fe0eebf5e446e3c998ec9bb19951541aee00bb90ea201ae456421a2ded86805,
            // automationUpdateInterval: 30, // 30 seconds
            // raffleEntranceFee: 0.01 ether,
            // callbackGasLimit: 500000, // 500,000 gas
            // vrfCoordinatorV2_5: 0x271682DEB8C4E0901D1a1550aD2e64D568E69909,
            // link: 0x514910771AF9Ca656af840dff83E8264EcF986CA
        });
    }

    function getOrCreateAnvilEthConfig() public returns (NetworkConfig memory) {
        // We need to deploy our own mock vrfCoordinator since this is not specified for anvil on chainlink
        if (localNetworkConfig.vrfCoordinator2_5 != address(0)) {
            return localNetworkConfig;
        }
        // Deploy mocks
        vm.startBroadcast();
        VRFCoordinatorV2_5Mock VrfCoordinatorMock = new VRFCoordinatorV2_5Mock(
            MOCK_BASE_FEE,
            MOCK_GAS_PRICE_LINK,
            MOCK_WEI_PER_UINT_LINK
        );
        LinkToken link = new LinkToken();
        vm.stopBroadcast();

        localNetworkConfig = NetworkConfig({
            entranceFee: 0.01 ether,
            interval: 30, // 30 seconds
            subscriptionId: 0, // our script will add this
            vrfCoordinator2_5: address(VrfCoordinatorMock),
            keyHash: 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae,
            callbackGasLimit: 500000, // 500,000 gas
            link: address(link),
            account: 0x1804c8AB1F12E6bbf3894d4083f33e07309d1f38
        });

        return localNetworkConfig;
    }
}
