// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// ERC-165 interfaceId:
// setTokenState(uint256,uint256,uint256) = 0x47b206b8
// getTokenState(uint256)                 = 0xf45fd0f3
// XORed                                  = 0xb3edd64b

// allow tokens to have a 256 bit state value
interface ITokenState {

    // announce a change in token state
    event TokenState(
        uint256 indexed tokenId,
        uint256 indexed state);

    // set the corresponding state
    // must be owner
    function setTokenState(uint256 tokenId, uint256 state, uint256 bribe) external;

    // get a token's state
    function getTokenState(uint256 tokenId) external view returns (uint256);

}
