// Layout of Contract:
// version
// imports
// errors
// interfaces, libraries, contracts
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// view & pure functions
// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";

/**
 * @title A sample Raffle Contract
 * @author Marvelous Afolabi
 * @notice This contract is for creating a sample raffle contract
 * @dev This implements the Chainlink VRF Version 2.5
 */

contract Raffle is VRFConsumerBaseV2Plus {
    error Raffle__NotEnoughTimeHasPassed();
    error Raffle__NotEnoughEntranceFeeSent();
    error Raffle__TransferFailed();
    error Raffle__NotOpen();
    error Raffle__NotUpkeepNeeded(
        uint256 balance,
        uint256 raffleState,
        uint256 numPlayers
    );

    /**Type declarations */
    enum RaffleState {
        OPEN, // converted to integer as 0
        CALCULATING // converted to integer as 1
    }

    uint256 private immutable i_entranceFee;
    uint256 private immutable i_interval;
    uint256 private immutable i_subscriptionId;
    address private immutable i_vrfCoordiantor;
    bytes32 private immutable i_keyHash;
    uint32 private immutable i_callbackGasLimit;
    uint16 private constant REQUEST_CONFIRMATION = 3;
    uint32 private constant NUM_WORDS = 1;
    uint256 private s_lastTimeStamp;
    address private s_recentWinner;
    address payable[] private s_participants;
    RaffleState private s_raffleState;

    event EnteredRaffle(address indexed player);
    event WinnerPicked(address indexed winner);
    event RequestedRaffleWinner(uint256 indexed requestId);

    constructor(
        uint256 entranceFee,
        uint interval,
        uint256 subscriptionId,
        address vrfCoordinator,
        bytes32 keyHash,
        uint32 callbackGasLimit
    ) VRFConsumerBaseV2Plus(vrfCoordinator) {
        i_entranceFee = entranceFee;
        s_lastTimeStamp = block.timestamp;
        i_interval = interval;
        i_keyHash = keyHash;
        i_callbackGasLimit = callbackGasLimit;
        i_subscriptionId = subscriptionId;
    }

    function enterRaffle() external payable {
        // Ensure they pay enough entrance fee
        if (msg.value < i_entranceFee) {
            revert Raffle__NotEnoughEntranceFeeSent();
        }

        if (s_raffleState != RaffleState.OPEN) {
            revert Raffle__NotOpen();
        }

        s_participants.push(payable(msg.sender));
        // emit an event after a user enters the raffle
        emit EnteredRaffle(msg.sender);
    }

    /** 
        @dev The checkUpkeep determines when we want the performUpkeep to be executed. When it returns true, the performUpkeep would be executed. 
        //  This should return true when
        *   1. When enough time has passed.
        *   2. when the players array is not 0. 
        *   3. The raffle is in the OPEN state.
            4. Contract has a balance
        *   5. (Implicit) The subscription is funded. with LINK

    */

    function checkUpkeep(
        bytes memory /* checkData */
    ) public view returns (bool upkeepNeeded, bytes memory /* performData */) {
        // be sure that enough time has passed
        bool timeHasPassed = ((block.timestamp - s_lastTimeStamp) >=
            i_interval);
        bool isRaffleOpen = s_raffleState == RaffleState.OPEN;
        bool hasPlayers = s_participants.length > 0;
        bool hasBalance = address(this).balance > 0;

        upkeepNeeded = (timeHasPassed &&
            isRaffleOpen &&
            hasPlayers &&
            hasBalance);

        return (upkeepNeeded, "0x0");
    }

    /**
        @dev pickWinner would be automated using chainlink Automation. 
     */
    function performUpkeep(bytes calldata /* performData */) external {
        (bool upkeepNeeded, ) = checkUpkeep("");
        if (!upkeepNeeded) {
            revert Raffle__NotUpkeepNeeded(
                address(this).balance,
                uint256(s_raffleState), // An enum can be converted to uint256.
                s_participants.length
            );
        }

        s_raffleState = RaffleState.CALCULATING;

        uint256 requestId = s_vrfCoordinator.requestRandomWords(
            VRFV2PlusClient.RandomWordsRequest({
                keyHash: i_keyHash,
                subId: i_subscriptionId,
                requestConfirmations: REQUEST_CONFIRMATION,
                callbackGasLimit: i_callbackGasLimit,
                numWords: NUM_WORDS,
                extraArgs: VRFV2PlusClient._argsToBytes(
                    // Set nativePayment to true to pay for VRF requests with Sepolia ETH instead of LINK
                    VRFV2PlusClient.ExtraArgsV1({nativePayment: false})
                )
            })
        );

        // This is redundant since the VRFCoordinator already emits this event.
        emit RequestedRaffleWinner(requestId);
    }

    /** This function is what happens after the request has been made successfully? The fufillRandomWords function needs to be callsed */
    /**
     * @notice Callback function used by VRF Coordinator to return the random number to this contract.
     *
     * @dev Some action on the contract state should be taken here, like storing the result.
     * @dev WARNING: take care to avoid having multiple VRF requests in flight if their order of arrival would result
     * in contract states with different outcomes. Otherwise miners or the VRF operator would could take advantage
     * by controlling the order.
     * @dev The VRF Coordinator will only send this function verified responses, and the parent VRFConsumerBaseV2
     * contract ensures that this method only receives randomness from the designated VRFCoordinator.
     *
      // * this should be at param requestIdd uint256
     * @param randomWords  uint256[] The random result returned by the oracle.
     */
    function fulfillRandomWords(
        uint256 /*requestId*/,
        uint256[] calldata randomWords
    ) internal override {
        uint256 randomNumber = randomWords[0];

        // Example of random word being returned is 203283729294040474466489399020374173
        // To get the index of the winner, we have to use modulue
        //  10 % 10, mudulo = 0, 10 % 9 = 1, 6 % 4 = 2
        uint256 winnerIndex = randomNumber % s_participants.length;
        address winner = s_participants[winnerIndex];
        s_recentWinner = winner;
        // reset the raffle state to open
        s_raffleState = RaffleState.OPEN;
        //    Send all money in the contract to the user
        (bool success, ) = winner.call{value: address(this).balance}("");

        if (!success) {
            revert Raffle__TransferFailed();
        }

        // reset the array
        s_participants = new address payable[](0);

        // reset the starting time
        s_lastTimeStamp = block.timestamp;

        // emit an event
        emit WinnerPicked(winner);
    }

    /** Getter functions */

    function getEntranceFee() public view returns (uint256) {
        return i_entranceFee;
    }

    function getRaffleState() public view returns (RaffleState) {
        return s_raffleState;
    }

    function getParticipants(uint256 index) public view returns (address) {
        return s_participants[index];
    }

    function getParticipantsLength() public returns (uint256) {
        return s_participants.length;
    }
}
