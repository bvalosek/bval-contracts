// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./interfaces/ISequenced.sol";
import "./@openzeppelin/ERC165.sol";

// Manage multiple parallel "sequences" Sequences can be "completed" in order to
// prevent any additional token numbers from being created for that sequence
abstract contract Sequenced is ERC165, ISequenced {

    // next sequence number to issue
    uint16 private _nextSequenceNumber = 1;

    // mapping from sequence number -> is complete
    mapping (uint16 => bool) private _completedSequences;

    // create a new sequence
    function _startSequence(
      uint16 sequenceNumber,
      string memory name,
      string memory description,
      string memory data) internal {
        require(sequenceNumber == _nextSequenceNumber, "wrong sequence number");
        _nextSequenceNumber++;
        emit SequenceMetadata(sequenceNumber, name, description, data);
    }

    // complete the sequence (no new tokens can be minted)
    function _completeSequence(uint16 sequenceNumber) internal {
      require(sequenceNumber > 0, "invalid sequence number");
      require(sequenceNumber < _nextSequenceNumber, "invalid sequence number");
      require(_completedSequences[sequenceNumber] == false, "sequence already complete");
      _completedSequences[sequenceNumber] = true;
      emit SequenceComplete(sequenceNumber);
    }

    // return true if a sequence is complete
    function sequenceComplete(uint16 sequenceNumber) public view returns (bool) {
      require(sequenceNumber > 0, "invalid sequence number");
      require(sequenceNumber < _nextSequenceNumber, "invalid sequence number");
      return _completedSequences[sequenceNumber];
    }

    // return total number of created sequences
    function totalSequences() external view returns (uint16) {
      return _nextSequenceNumber - 1;
    }

    // ERC165
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
      return interfaceId == type(ISequenced).interfaceId || super.supportsInterface(interfaceId);
    }

}
