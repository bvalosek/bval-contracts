// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// interface for announcing token metadata on chain
interface ITokenMetadata {

    // announce token metadata
    // MUST be emitted on mint
    event TokenMetadata(
        uint256 indexed tokenId,
        string name,
        string description,
        string data);

}
