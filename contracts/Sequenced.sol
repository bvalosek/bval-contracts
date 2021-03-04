// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./interfaces/ISequenced.sol";

// Manage multiple parallel "sequences" Sequences can be "completed" in order to
// prevent any additional tokens from being minted for that sequence
abstract contract Sequenced is ISequenced {

    // mapping from sequence number to state;
    mapping (uint16 => SequenceState) private _sequences;

    // create a new sequence
    function _startSequence(
      uint16 number,
      string memory name,
      string memory description,
      string memory data) internal {
        require(number > 0, "invalid sequence number");
        require(_sequences[number] == SequenceState.NOT_STARTED, "sequence already started");
        _sequences[number] = SequenceState.STARTED;
        emit SequenceMetadata(number, name, description, data);
    }

    // complete the sequence (no new tokens can be minted)
    function _completeSequence(uint16 number) internal {
      require(_sequences[number] == SequenceState.STARTED, "sequence not active");
      _sequences[number] = SequenceState.COMPLETED;
      emit SequenceComplete(number);
    }

    // determine status of sequence
    function getSequenceState(uint16 number) public view returns (SequenceState) {
      require(number > 0, "invalid sequence number");
      return _sequences[number];
    }

}
