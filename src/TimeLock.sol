// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {TimelockController} from "../lib/openzeppelin-contracts/contracts/governance/TimelockController.sol";

contract TimeLock is TimelockController {
    //min delay is how long you have to wait before executing

    constructor(
        uint256 minDelay,
        address[] memory proposers,
        address[] memory executors
    ) TimelockController(minDelay, proposers, executors, msg.sender) {}
}
