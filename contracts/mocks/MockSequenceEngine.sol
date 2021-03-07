// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../interfaces/ISequenced.sol";

contract MockSequenceEngine is ISequenceEngine {

  function processStateChange (
    uint256 tokenId,
    address owner,
    uint256 input,
    uint256 state) override external pure returns (uint256) {
      require(tokenId != 0);
      require(owner != address(0));
      return state + input;
    }
}
