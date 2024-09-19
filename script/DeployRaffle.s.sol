// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Script} from "forge-std/Script.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {Raffle} from "../src/Raffle.sol";
import {CreateSubscription, FundSubscription, AddConsumer} from "./Interactions.s.sol";

contract DeployRaffle is Script {
    function run() public {
        // We have to do this if we want to run it as a script.
        
        deployContract();
    }

    function deployContract() public returns (Raffle, HelperConfig) {
        HelperConfig helperConfig = new HelperConfig();

        // local chain -> deploys mocks, get local config
        // sepolia -> get sepolia config straight

        //  The commented out code below works too

        // (
        //     uint256 entranceFee,
        //     uint interval,
        //     uint256 subscriptionId,
        //     address vrfCoordinator2_5,
        //     bytes32 keyHash,
        //     uint32 callbackGasLimit,
        //     address link,

        // ) = helperConfig.getConfig();

        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();

        if (config.subscriptionId == 0) {
            CreateSubscription createSubscription = new CreateSubscription();

            (
                config.subscriptionId,
                config.vrfCoordinator2_5
            ) = createSubscription.createSubscription(config.vrfCoordinator2_5);

            // Fund the subscription.
            FundSubscription fundSubscription = new FundSubscription();

            fundSubscription.fundSubscription(
                config.vrfCoordinator2_5,
                config.link,
                config.subscriptionId
            );
        }

        vm.startBroadcast();
        Raffle raffle = new Raffle(
            config.entranceFee,
            config.interval,
            config.subscriptionId,
            config.vrfCoordinator2_5,
            config.keyHash,
            config.callbackGasLimit
        );
        vm.stopBroadcast();

        // We only add consumer after the contract has been deoloyed since it is the latest deployed contract
        //we are passing to the consumer function

        AddConsumer addConsumer = new AddConsumer();
        addConsumer.addConsumer(
            address(raffle),
            config.vrfCoordinator2_5,
            config.subscriptionId
        );

        return (raffle, helperConfig);
    }
}
