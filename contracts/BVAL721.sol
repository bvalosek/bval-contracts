// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// import "./interfaces/ITokenState.sol";

import "./Base721.sol";
import "./TokenID.sol";
// import "./BVAL20.sol";

contract BVAL721 is Base721 {
  using TokenID for uint256;

  string private constant NAME = "@bvalosek Collection";
  string private constant DESCRIPTION = "Dynamic and interactive NFTs featuring the abstract digital art of Brandon Valosek";
  string private constant DATA = "QmTC2N4rXQfnPmHUQEgLPYtfFHryoxWQEDsrTWFg8RffTk";
  string private constant SYMBOL = "BVAL-NFT";
  uint16 private constant FEE_BPS = 1000;

  // individual token state
  mapping (uint256 => uint256) private _tokenStates;

  // mapping from a token ID to when its state lock expires
  mapping (uint256 => uint) private _tokenLockExpiresAt;

  constructor (string memory baseURI) Base721(ContractOptions({
    name: NAME,
    description: DESCRIPTION,
    data: DATA,
    symbol: SYMBOL,
    feeBps: FEE_BPS,
    baseURI: baseURI
  })) {

  }

  // ---
  // Token State
  // ---

  // lock a set of tokens for 24 hours
  function lockTokens(uint256[] calldata tokenIds) external {
    uint expiresAt = block.timestamp + 60 * 60 * 24;
    for (uint i = 0; i < tokenIds.length; i++) {
      uint256 tokenId = tokenIds[i];
      require(_exists(tokenId), "invalid token");
      _tokenLockExpiresAt[tokenId] = expiresAt;
    }
  }

  // determine what time a token expires at
  function tokenLockExpiresAt(uint256 tokenId) external view returns (uint) {
    require(_exists(tokenId), "invalid token");
    return _tokenLockExpiresAt[tokenId];
  }

  // // set the state of a token
  // // msg.sender MUST be approved or owner
  // function setTokenState(uint256 tokenId, uint256 state, uint256 bribe) override external {
  //   require(_isApprovedOrOwner(_msgSender(), tokenId), "not token owner");

  //   // only care about the $BVAL contract if token has a state change cost
  //   uint16 costMult = tokenId.tokenStateChangeCost();
  //   if (costMult > 0 || bribe > 0) {
  //     require(_coinContract != BVAL20(address(0)), "coin address not yet set");
  //     uint256 cost = uint256(costMult) * 10 ** _coinContract.decimals();
  //     cost += bribe;
  //     _coinContract.transferFrom(_msgSender(), address(this), cost);
  //     _coinContract.burn(cost);
  //   }

  //   // hook for future functionality
  //   ISequenceEngine engine = _sequenceEngines[tokenId.tokenSequenceNumber()];
  //   if (engine != ISequenceEngine(address(0))) {
  //     state = engine.processStateChange(
  //       tokenId,
  //       ownerOf(tokenId),
  //       _tokenStates[tokenId],
  //       state,
  //       bribe);
  //   }

  //   _tokenStates[tokenId] = state;
  //   emit TokenState(tokenId, state);
  // }

  // // read the state of a token
  // function getTokenState(uint256 tokenId) override external view returns (uint256) {
  //   require(_exists(tokenId), "invalid token");
  //   return _tokenStates[tokenId];
  // }





}
