# bval-contracts

Solidity smart contracts for the BVAL-NFT project.

## Development

Install all deps

```
$ npm i
```

Start local blockchain

```
$ npm run blockchain:local
```

Run truffle tests

```
$ npm test
```

Compile and build all contracts

```
$ npm run build
```

## Overview

This repo has an ERC-721 and an ERC-20 contract that are designed to work together:

### ERC-721

#### Implementation Base

Based on a modified version of the latest ERC-721 implementation from OpenZeppelin (to cut gas a bit):

* Removes dynamic length `string` storage
* Removes metadata extension
* Removes hook function

#### Token ID encoding

The 256 bits of the ERC-721 tokenID are used to encode information about the token. This allows for immutable, intrinsic information about a token to be represented on-chain in an ERC-721 compat way.

* Token number, sequence number, collection version
* Mint date and created date
* $BVAL emission rate and state change cost
* Edition number / edition total
* Information about the asset (resolution, type)
* etc...

#### Sequences

See `Sequenced.sol`

* A sequence is a series of tokens
* Each token belongs to a single sequence
* A token's sequence is encoded into its ID (see token ID encoding)
* A sequence can be "completed", preventing any further tokens from being minted in that sequence
* A sequence cannot be re-started once completed
* Multiple sequences may be started in parallel

#### On-chain Metadata via Events

On-chain events are emitted to announce collection/sequence/token metadata in a durable way:

* In the constructor, a `CollectionMetadata` event is published
* Whenever a sequence is started, a `SequenceMetadata` event is published
* Whenever a token is minted, a `TokenMetadata` event is published
* Whenever a sequence is completed, a `SequenceComplete` event is published

#### Token State

* Each token has a `uint256` state value associated with it
* Only the token holder can set this state
* State can be set to any arbitrary value
* State is designed to be used to build on and off chain experiences in the future
* Changing state may require $BVAL
* State change cost is an intrinsic property of a token (encoded into its ID)


### ERC-20

#### Implementation Base

Based on a modified version of the latest ERC-20 implementation from OpenZeppelin (to cut gas a bit):

* Removes dynamic length `string` storages for symbol/name
* Removes hook function

#### Collection Registration

* A mapping can be set by the contract owner from a token version to a contract address
* This mapping can only be set once
* This is used to resolve the above ERC-721 contract from the collection version extracted from a NFT token ID

#### Claiming $BVAL

* The holder of a BVAL-NFT can call the `claim` method with an array of token IDs
* NFTs "emit" $BVAL at a rate determined by an emission rate encoded into their token IDs
* Calling `claim` will mint new $BVAL corresponding to how much has been emitted since the last claim

#### Deadman Switch

* The `pingDeadmanSwitch` method must be called once a year, or $BVAL emission will stop (claims still still occur for outstanding $BVAL)
* Once the switch is tripped, there's no way to reset it
