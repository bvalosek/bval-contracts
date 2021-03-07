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

This repo has an ERC-721 and an ERC-20 contract that are designed to work together (`BVAL721` and `BVAL20`). Some of the market interop and basic 721 improvements are pulled into a generalized `Base721` contract, and the sequencing and minting functionality is implemented in `Sequenced721`. Inheritance is so un-ergonomic but when in rome...

Both `BVAL*` contracts inherit from OpenZeppelin's `AccessControlEnumerable` contract to enable enumerable RBAC support. The design goal for my contracts was to allow very pervasive control of contract parameters and functionality behind roles that I can eventually renounce or give exclusively to less pervasive proxy smart contracts (or even a DAO).

The idea with this was to enable flexible extension and future functionality as I iterate on this project while still allowing for more iterative delegated trust over time.

### ERC-721

#### Implementation Base

* OpenZeppelin ERC-721 w/ the Enumerable extension implementation
* Includes `AccessControlEnumerable` for enumerable RBAC support

#### Token ID encoding

The 256 bits of the ERC-721 tokenID are used to encode information about the token. This allows for immutable, intrinsic information about a token to be represented on-chain in an ERC-721 compat way.

* Token number, sequence number
* Mint date and created date
* $BVAL yield and burn multipliers
* Edition number / edition total
* Information about the asset (resolution, type)
* etc...

Some of this information is checked on chain (see `TokenID.sol`), but most of it is used for the corresponding `tokens.bvalosek.com` gallery site.

#### Sequences

See `Sequenced.sol`

* A sequence is a series of tokens
* Each token belongs to a single sequence
* A token's sequence is encoded into its ID (see token ID encoding)
* A sequence can be "completed", preventing any further tokens from being minted in that sequence
* A sequence cannot be re-started once completed
* Multiple sequences may be started in parallel
* A sequence may be registered with an "engine", which will be called during token state changes

A sequence is considered "atomic" if it was created with the `mintAtomicSequence` function, which will start a sequence, mint NFTs, and complete a sequence in a single transaction.

##### Sequence Engines

Sequence engines allow for additional on-chain behaviors and mechanics to be added after the initial contract deploys.

* A sequence engine is registered for a specific sequence, and invoked anytime state is set for a token in that sequence
* A sequence engine implements a single method that is called during token state change
* The sequence engine can validate the state change or cause additional side effects
* The engine may override the value that is actually written to token state

#### On-chain Metadata via Events

On-chain events are emitted to announce collection/sequence/token metadata in a durable way:

* In the constructor, a `CollectionMetadata` event is published
* Whenever a sequence is started, a `SequenceMetadata` event is published
* Whenever a token is minted, a `TokenMetadata` event is published
* Whenever a sequence is completed, a `SequenceComplete` event is published

#### Token State

* Each token has a `uint256` state value associated with it
* Only the token holder can set this state
* State can be set to any arbitrary value if no sequence engine is specified
* State changes may be modified or constrained by a sequence engine
* State is designed to be used to build on and off chain experiences in the future
* Changing state may require $BVAL (as determined by the NFT's burn multiplier)
* State change cost is an intrinsic property of a token (encoded into its ID)

#### Marketplace Interop

* Implements Rarible's royalty interface
* Implements OpenSea's collectionURI interface
* Implements EIP-2981 royalty spec

### ERC-20

#### Implementation Base

* OpenZeppelin ERC-20
* Includes `AccessControlEnumerable` for enumerable RBAC support

#### Deadman Switch

* The `pingDeadmanSwitch` method must be called once a year, or minting any more BVAL is impossible
* Once the switch is tripped, there's no way to reset it
