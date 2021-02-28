// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

library TokenID {

  function tokenSequenceNumber(uint256 tokenId) internal pure returns (uint16) {
    return uint16(tokenId >> 2*8);
  }

  function tokenCollectionVersion(uint256 tokenId) internal pure returns (uint16) {
    return uint16(tokenId >> 4*8);
  }

  function tokenMintTimestamp(uint256 tokenId) internal pure returns (uint) {
    uint16 daystamp = uint16(tokenId >> 10*8);
    return uint(daystamp) * 60 * 60 * 24;
  }

  function tokenEmissionRate(uint256 tokenId) internal pure returns (uint16) {
    return uint16(tokenId >> 26*8);
  }

  function tokenStateChangeCost(uint256 tokenId) internal pure returns (uint16) {
    return uint16(tokenId >> 28*8);
  }

  function tokenChecksum(uint256 tokenId) internal pure returns (uint8) {
    return uint8(tokenId >> 30*8);
  }

  function tokenVersion(uint256 tokenId) internal pure returns (uint8) {
    return uint8(tokenId >> 31*8);
  }

  function isTokenValid(uint256 tokenId) internal pure returns (bool) {
    uint8 checksum = TokenID.tokenChecksum(tokenId);
    uint256 masked = tokenId & 0xff00ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff;
    uint8 computed = uint8(uint256(keccak256(abi.encodePacked(masked))));
    return checksum == computed;
  }

}
