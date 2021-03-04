// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// allow parallel sequences to be started and completed
interface ISequenced {

    // state of a sequence
    enum SequenceState {
      NOT_STARTED,
      STARTED,
      COMPLETED
    }

    // announce sequence data
    event SequenceMetadata(
      uint16 indexed number,
      string name,
      string description,
      string data);

    // announce sequence complete
    event SequenceComplete(uint16 indexed number);

    // start a new sequence
    function startSequence(
      uint16 number,
      string memory name,
      string memory description,
      string memory data) external;

    // complete a started sequence
    function completeSequence(uint16 number) external;
}
