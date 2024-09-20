// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {HelperConfig, CodeConstants} from "script/HelperConfig.s.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {LinkToken} from "../test/mocks/LinkToken.sol";
import {DevOpsTools} from "lib/foundry-devops/src/DevOpsTools.sol";

contract CreateSubscription is Script {
    function createSubscriptionUsingConfig() public returns (uint256, address) {
        HelperConfig helperConfig = new HelperConfig();

        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();
        address vrfCoordinator = config.vrfCoordinator2_5;

        (uint256 subId, ) = createSubscription(vrfCoordinator);
        return (subId, vrfCoordinator);
    }

    function createSubscription(
        address vrfCoordinator
    ) public returns (uint256, address) {
        console.log("Creating subscription on ChainId", block.chainid);

        vm.startBroadcast();
        uint256 subId = VRFCoordinatorV2_5Mock(vrfCoordinator)
            .createSubscription();
        vm.stopBroadcast();
        console.log("Your subId is", subId);
        console.log("SubId needs to be updated in Helperconfig.s.sol");
        return (subId, vrfCoordinator);
    }

    function run() public {
        createSubscriptionUsingConfig();
    }
}

contract FundSubscription is Script, CodeConstants {
    uint256 private constant FUND_AMOUNT = 3 ether;

    function fundSubscriptionWithConfig() public {
        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();

        address vrfCoordinator = config.vrfCoordinator2_5;
        uint256 subId = config.subscriptionId;
        address linkToken = config.link;

        fundSubscription(vrfCoordinator, linkToken, subId);
    }

    function fundSubscription(
        address vrfCoordinator,
        address linkToken,
        uint256 subId
    ) public {
        console.log("Funding Subscription with", FUND_AMOUNT);
        console.log("Using vrfCoordinator:", vrfCoordinator);
        console.log("On ChainId:", block.chainid);

        if (block.chainid == LOCAL_CHAIN_ID) {
            vm.startBroadcast();
            VRFCoordinatorV2_5Mock(vrfCoordinator).fundSubscription(
                subId,
                FUND_AMOUNT * 100
            );
            vm.stopBroadcast();
        } else {
            vm.startBroadcast();
            LinkToken(linkToken).transferAndCall(
                vrfCoordinator,
                FUND_AMOUNT,
                abi.encode(subId)
            );
            vm.stopBroadcast();
        }
    }

    function run() public {
        fundSubscriptionWithConfig();
    }
}

contract AddConsumer is Script {
    function addConsumerUisngConfig(address mostRecentlyDeployed) public {
        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();

        address vrfCoordinator = config.vrfCoordinator2_5;
        uint256 subId = config.subscriptionId;

        addConsumer(mostRecentlyDeployed, vrfCoordinator, subId);
    }

    function addConsumer(
        address contractToAddtoVrf,
        address vrfCoordinator,
        uint256 subId
    ) public {
        console.log("Adding consumer to VRF Coordinator:", contractToAddtoVrf);
        console.log("To VrfCoordinator:", vrfCoordinator);
        console.log("On chainId", block.chainid);

        vm.startBroadcast();
        VRFCoordinatorV2_5Mock(vrfCoordinator).addConsumer(
            subId,
            contractToAddtoVrf
        );
        vm.stopBroadcast();
    }

    function run() public {
        address mostRecentlyDeployed = DevOpsTools.get_most_recent_deployment(
            "Raffle",
            block.chainid
        );

        addConsumerUisngConfig(mostRecentlyDeployed);
    }
}
