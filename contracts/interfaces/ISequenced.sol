// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// allow parallel sequences to be started and completed
interface ISequenced {

    // announce sequence data
    event SequenceMetadata(
      uint16 indexed sequenceNumber,
      string name,
      string description,
      string data);

    // announce sequence complete
    event SequenceComplete(uint16 indexed sequenceNumber);

    // start a new sequence
    // must be owner
    function startSequence(
      uint16 sequenceNumber,
      string memory name,
      string memory description,
      string memory data) external;

    function completeSequence(uint16 sequenceNumber) external;

}
