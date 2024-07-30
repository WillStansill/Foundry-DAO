// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {MyGovernor} from "../src/MyGovernor.sol";
import {GovToken} from "../src/GovToken.sol";
import {TimeLock} from "../src/TimeLock.sol";
import {Box} from "../src/Box.sol";

contract MyGovernorTest is Test {
    GovToken token;
    TimeLock timelock;
    MyGovernor governor;
    Box box;

    uint256 public constant MIN_DELAY = 3600; // 1 hour - after a vote passes, you have 1 hour before you can enact
    uint256 public constant QUORUM_PERCENTAGE = 4; // Need 4% of voters to pass
    uint256 public constant VOTING_PERIOD = 50400; // This is how long voting lasts
    uint256 public constant VOTING_DELAY = 7200; // How many blocks till a proposal vote becomes active

    address[] proposers;
    address[] executors;

    bytes[] functionCalls;
    address[] addressesToCall;
    uint256[] values;

    address public constant VOTER = address(1);
    function setUp() public {
        token = new GovToken();

        // Transfer tokens from the test contract (msg.sender) to the VOTER
        token.transfer(VOTER, 10 * 10 ** token.decimals());
        console.log("VOTER token balance:", token.balanceOf(VOTER));

        // Ensure VOTER delegates votes to themselves
        vm.prank(VOTER);
        token.delegate(VOTER);
        console.log("VOTER delegated votes:", token.getVotes(VOTER));

        timelock = new TimeLock(MIN_DELAY, proposers, executors);
        governor = new MyGovernor(token, timelock);

        bytes32 proposerRole = timelock.PROPOSER_ROLE();
        bytes32 executorRole = timelock.EXECUTOR_ROLE();
        bytes32 adminRole = timelock.DEFAULT_ADMIN_ROLE();

        timelock.grantRole(proposerRole, address(governor));
        timelock.grantRole(executorRole, address(0));
        timelock.revokeRole(adminRole, msg.sender);

        box = new Box();
        box.transferOwnership(address(timelock));
    }

    function testGovernanceUpdatesBox() public {
        uint256 valueToStore = 777;
        string memory description = "Store 1 in Box";
        bytes memory encodedFunctionCall = abi.encodeWithSignature(
            "store(uint256)",
            valueToStore
        );

        addressesToCall.push(address(box));
        values.push(0);
        functionCalls.push(encodedFunctionCall);

        // 1. Propose to the DAO
        uint256 proposalId = governor.propose(
            addressesToCall,
            values,
            functionCalls,
            description
        );

        // Log initial proposal state
        console.log(
            "Initial Proposal State:",
            uint256(governor.state(proposalId))
        ); // Should be Pending (0)

        // Fetch proposal details
        console.log(
            "Proposal Snapshot:",
            governor.proposalSnapshot(proposalId)
        );
        console.log(
            "Proposal Deadline:",
            governor.proposalDeadline(proposalId)
        );

        // Advance time and block number for voting delay
        vm.warp(block.timestamp + VOTING_DELAY + 1);
        vm.roll(block.number + VOTING_DELAY + 1);

        // Log proposal state after voting delay
        console.log(
            "Proposal State after Voting Delay:",
            uint256(governor.state(proposalId))
        ); // Should be Active (1)

        // 2. Vote
        string memory reason = "I like a do da cha cha";
        uint8 voteWay = 1; // 0 = Against, 1 = For, 2 = Abstain

        vm.prank(VOTER);
        governor.castVoteWithReason(proposalId, voteWay, reason);

        // Advance time and block number for voting period
        vm.warp(block.timestamp + VOTING_PERIOD + 1);
        vm.roll(block.number + VOTING_PERIOD + 1);

        // Log proposal state after voting period
        console.log(
            "Proposal State after Voting Period:",
            uint256(governor.state(proposalId))
        ); // Should be Succeeded (4)

        // 3. Queue
        bytes32 descriptionHash = keccak256(abi.encodePacked(description));
        governor.queue(addressesToCall, values, functionCalls, descriptionHash);

        vm.warp(block.timestamp + MIN_DELAY + 1);
        vm.roll(block.number + MIN_DELAY + 1);

        // Log proposal state after queuing
        console.log(
            "Proposal State after Queuing:",
            uint256(governor.state(proposalId))
        ); // Should be Queued (5)

        // 4. Execute
        governor.execute(
            addressesToCall,
            values,
            functionCalls,
            descriptionHash
        );

        // Log final state
        console.log(
            "Final Proposal State:",
            uint256(governor.state(proposalId))
        ); // Should be Executed (7)

        // Check the Box state
        assert(box.getNumber() == valueToStore);
    }
}
