// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./Base721.sol";
import "./Sequenced.sol";
import "./TokenID.sol";

// Builds on top of the Base721 implementation to add in the minting mechanics
// and handling sequences
contract Sequenced721 is Base721, Sequenced {
  using TokenID for uint256;

  constructor (ContractOptions memory options) Base721(options) { }

  // ---
  // Minting
  // ---

  // mint a new token for the contract owner and emit metadata as an event
  function mint(
    uint256 tokenId,
    string memory name_,
    string memory description_,
    string memory data_) external {
      address msgSender = _msgSender();
      require(hasRole(MINTER_ROLE, msgSender), "requires MINTER_ROLE");
      require(tokenId.isTokenValid() == true, "malformed token");
      require(tokenId.tokenVersion() > 0, "invalid token version");
      require(getSequenceState(tokenId.tokenSequenceNumber()) == SequenceState.STARTED, "sequence is not active");

      _mint(msgSender, tokenId);
      emit TokenMetadata(tokenId, name_, description_, data_);
      _emitSecondarySaleInfo(tokenId);
  }

  // ---
  // Sequences
  // ---

  // start sequence
  function startSequence(
    uint16 number,
    string memory name_,
    string memory description_,
    string memory data_) override external {
      require(hasRole(MINTER_ROLE, _msgSender()), "requires MINTER_ROLE");
      _startSequence(number, name_, description_, data_);
  }

  // complete the sequence
  function completeSequence(uint16 number) override external {
    require(hasRole(MINTER_ROLE, _msgSender()), "requires MINTER_ROLE");
    _completeSequence(number);
  }

}
