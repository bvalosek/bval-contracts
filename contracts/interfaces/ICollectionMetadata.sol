// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// interface for announcing collection metadata on chain
interface ICollectionMetadata {

    // announce collection data
    // must emit on contract instantiation
    event CollectionMetadata(
        string name,
        string description,
        string data);

}
