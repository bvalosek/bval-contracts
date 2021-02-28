// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../interfaces/ISequenced.sol";

contract MockSequenceEngine is ISequenceEngine {

  uint256 private _count = 0;

  function count() public view returns (uint256) {
    return _count;
  }

  function processStateChange (
    uint256 tokenId,
    address owner,
    uint256 currentState,
    uint256 nextState,
    uint256 bribe) override external returns (uint256) {
      return ++_count;
    }
}
