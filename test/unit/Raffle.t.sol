//// SPDX-License-Identifier: MIT

pragma solidity 0.8.24;
import {Test, console} from "forge-std/Test.sol";
import {DeployRaffle} from "../../script/DeployRaffle.s.sol";
import {Raffle} from "../../src/Raffle.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {Vm} from "forge-std/Vm.sol";

contract RaffleTest is Test {
    /**  Event */

    event EnteredRaffle(address indexed player);

    Raffle private raffle;
    HelperConfig private helperConfig;

    address public player = makeAddr("Player");
    uint256 public constant STARTING_USER_BALANCE = 10 ether;

    uint256 entranceFee;
    uint interval;
    uint256 subscriptionId;
    address vrfCoordinator2_5;
    bytes32 keyHash;
    uint32 callbackGasLimit;
    address linkToken;

    function setUp() public {
        DeployRaffle deployer = new DeployRaffle();
        (raffle, helperConfig) = deployer.deployContract();

        // (
        //     entranceFee,
        //     interval,
        //     subscriptionId,
        //     vrfCoordinator2_5,
        //     keyHash,
        //     callbackGasLimit,
        //     linkToken
        // ) = helperConfig.getConfig();

        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();

        entranceFee = config.entranceFee;
        interval = config.interval;
        subscriptionId = config.subscriptionId;
        vrfCoordinator2_5 = config.vrfCoordinator2_5;
        keyHash = config.keyHash;
        callbackGasLimit = config.callbackGasLimit;
        linkToken = config.link;

        vm.deal(player, STARTING_USER_BALANCE);
    }

    function testRaffleInitializesInOpenState() public view {
        assert(raffle.getRaffleState() == Raffle.RaffleState.OPEN);
    }

    /*//////////////////////////////////////////////////////////////
                   ENTERS RAFFLE WITHOUT ENTRANCE FEE
    //////////////////////////////////////////////////////////////*/
    function testRaffleRevertsWhenYouDontPayENough() public {
        // Arramge
        vm.prank(player);

        // Act / Assert
        // This expects the line following it to revert
        vm.expectRevert(Raffle.Raffle__NotEnoughEntranceFeeSent.selector);
        raffle.enterRaffle();
    }

    function testRaffleRecordsPlayerWhenTheyEnter() public {
        // Arrange
        vm.prank(player);

        // Assert / Arrange
        raffle.enterRaffle{value: entranceFee}();
        // assertEq(address(player), raffle.getParticipants(0));
        assert(address(player) == raffle.getParticipants(0));
    }

    function testEmitsEventOnRaffleEntrance() public {
        vm.prank(player);

        // Topics are also known as indexed parameters in an array
        // We have only one topic here, hence the reason why we have true on the first argument.
        // The second to last argument is checking for non index parameter in the event
        // the last argument is the address of the contract that emits the event.

        vm.expectEmit(true, false, false, false, address(raffle));
        // we manually emit the event and call the function that emits the event

        // We perform the call here.
        raffle.enterRaffle{value: entranceFee}();
    }

    function testCantEnterWhenRaffleIsCalculating() public {
        // Arrange (based on the conditions that sets performUpkeep to true)
        // Perform upkeep triggers the raffleState to calculating
        // We do not need to check whether raffle is in open state here since we checked in the first test.

        vm.prank(player);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        raffle.performUpkeep(""); // This will set state to calculating

        // Act (We expect the test to revert when a user now tries to enter the raffle)
        vm.expectRevert(Raffle.Raffle__NotOpen.selector);
        vm.prank(player);
        raffle.enterRaffle{value: entranceFee}();
    }

    /*//////////////////////////////////////////////////////////////
                              CHECK UPKEEP
    //////////////////////////////////////////////////////////////*/

    function testPerformUpkeepFailsIfNoBalance() public {
        // Arrange
        vm.prank(player);
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        // Here, upkeep should not be needed since we did not enter the raffle, hence raffle has no balance
        // Act
        (bool upkeepNeeded, ) = raffle.checkUpkeep("");
        //  Assert
        assert(!upkeepNeeded);
    }

    function testPerformUpkeepFailsIfRaffleIsNotOpen() public {
        // Act
        vm.prank(player);
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        raffle.performUpkeep("");
        raffle.enterRaffle{value: entranceFee}();

        // Act
        (bool upkeepNeeded, ) = raffle.checkUpkeep("");

        // Assert
        assert(!upkeepNeeded);
    }

    /*//////////////////////////////////////////////////////////////
        ENOUGH TIME HAS PASSED AND UPKEEP RETURNS TRUE
    //////////////////////////////////////////////////////////////*/
    function testCheckUpkeepReturnsFalseIfEnoughTimeHasNotPassed() public {
        // Arrange
        vm.prank(player);
        vm.warp(block.timestamp);
        vm.roll(block.number);
        raffle.enterRaffle{value: entranceFee}();
        // Act
        (bool upkeepNeeded, ) = raffle.checkUpkeep("");

        // Assert
        assert(!upkeepNeeded);
    }

    /*//////////////////////////////////////////////////////////////
        ENOUGH TIME HAS PASSED AND UPKEEP RETURNS TRUE
    //////////////////////////////////////////////////////////////*/

    function testUpkeepReturnsTrueWhenParametersAreGood() public {
        // Arrange
        vm.prank(player);
        // Enough time has passed
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        // Add Money to contract by adding players in the raffle
        raffle.enterRaffle{value: entranceFee}();

        // Act
        (bool upkeepNeeded, ) = raffle.checkUpkeep("");

        // Assert
        assert(upkeepNeeded);
    }

    /*//////////////////////////////////////////////////////////////
        PERFORM UPKEEP
    //////////////////////////////////////////////////////////////*/

    function testPerformUpkeepCanOnlyRunIfCheckUpkeepIsTrue() public {
        // Arrange
        vm.prank(player);
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        raffle.enterRaffle{value: entranceFee}();
        // Act / Assert
        raffle.performUpkeep("");
    }

    function testPerformUpkeepDoesNotRunIfCheckUpkeepIsFalse() public {
        uint256 balance = 0;
        uint256 numPlayers = 0;
        Raffle.RaffleState rState = raffle.getRaffleState();

        // Arrange
        vm.prank(player);
        vm.warp(block.timestamp);
        vm.roll(block.number);
        raffle.enterRaffle{value: entranceFee}();

        numPlayers = 1;
        balance = balance + entranceFee;
        // Act
        //  ==> since checkUpkeep fails here, performUpkeep is going to revert.
        vm.expectRevert(
            abi.encodeWithSelector(
                Raffle.Raffle__NotUpkeepNeeded.selector,
                balance,
                rState,
                numPlayers
            )
        );
        raffle.performUpkeep("");
    }

    modifier raffleEntered() {
        vm.prank(player);
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        raffle.enterRaffle{value: entranceFee}();
        _;
    }

    function testPerformUpkeepUpdatesRaffleStateAndEmitRequestId()
        public
        raffleEntered
    {
        vm.recordLogs();
        raffle.performUpkeep("");
        Vm.Log[] memory entries = vm.getRecordedLogs();

        bytes32 requestId = entries[1].topics[1];

        // Assert
        Raffle.RaffleState raffleState = raffle.getRaffleState();

        assert(uint256(requestId) > 0);
        assert(uint256(raffleState) == 1);
    }

    /*//////////////////////////////////////////////////////////////
                             FULLFIL RANDOMWORDS
    //////////////////////////////////////////////////////////////*/
}
