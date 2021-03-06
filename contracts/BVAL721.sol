// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./@openzeppelin/IERC20.sol";

import "./Base721.sol";
import "./TokenID.sol";

contract BVAL721 is Base721 {
  using TokenID for uint256;

  // immutable contract information
  string private constant NAME = "@bvalosek Collection";
  string private constant DESCRIPTION = "Dynamic and interactive NFTs featuring the abstract digital art of Brandon Valosek";
  string private constant DATA = "QmTC2N4rXQfnPmHUQEgLPYtfFHryoxWQEDsrTWFg8RffTk";
  string private constant SYMBOL = "BVAL-NFT";
  uint16 private constant FEE_BPS = 1000;

  uint internal constant ONE_DAY =  60 * 60 * 24;
  uint internal constant ONE_YEAR = 60 * 60 * 24 * 365;

  IERC20 private immutable _bvalTokenContract;

  // base BVAL/day accumulation rate before token yield multiplier is applied
  uint256 private _baseDailyRate = 10 ** 18;

  // individual token state
  mapping (uint256 => uint256) private _tokenStates;

  // mapping from a token ID to when its state lock expires
  mapping (uint256 => uint) private _tokenLockExpiresAt;

  // mapping from a token ID to the last claim timestamp
  mapping (uint256 => uint) private _lastClaimTimestamp;

  constructor (string memory baseURI, IERC20 bvalTokenContract) Base721(ContractOptions({
    name: NAME,
    description: DESCRIPTION,
    data: DATA,
    symbol: SYMBOL,
    feeBps: FEE_BPS,
    baseURI: baseURI
  })) {
    _bvalTokenContract = bvalTokenContract;
  }

  // ---
  // Token State
  // ---

  // lock a set of tokens for 24 hours
  function lockTokens(uint256[] calldata tokenIds) external {
    uint expiresAt = block.timestamp + 60 * 60 * 24;
    address msgSender = _msgSender();
    for (uint i = 0; i < tokenIds.length; i++) {
      uint256 tokenId = tokenIds[i];
      require(_isApprovedOrOwner(msgSender, tokenId), "not token owner");
      _tokenLockExpiresAt[tokenId] = expiresAt;
    }
  }

  // determine what time a token expires at
  function tokenLockExpiresAt(uint256 tokenId) external view returns (uint) {
    require(_exists(tokenId), "invalid token");
    return _tokenLockExpiresAt[tokenId];
  }

  // get the current token state
  function tokenState(uint256 tokenId) external view returns (uint256) {
    require(_exists(tokenId), "invalid token");
    return _tokenStates[tokenId];
  }

  // ---
  // $BVAL
  // --

  // determine the accumulated BVAL for a given token
  function accumulated(uint256 tokenId) public view returns (uint256) {
    uint yieldStart = tokenId.tokenMintTimestamp();
    uint yieldStop = block.timestamp;

    // determine when we should claim from, either the last claim recorded or
    // the start of generation if no claims have been made
    uint lastClaim = _lastClaimTimestamp[tokenId];
    uint claimFrom = lastClaim != 0 ? lastClaim : yieldStart;

    // determine period in seconds to claim for, 0 if negative (mint in future)
    uint period = yieldStop > claimFrom ? yieldStop - claimFrom : 0;

    // compute how much bval to transfer
    uint256 dailyRate = tokenId.tokenYieldMultiplier() * _baseDailyRate;
    uint256 toClaim = period * dailyRate / ONE_DAY;

    return toClaim;
  }

  // claim all BVAL accumulated on a list of tokens
  function claim(uint256[] memory tokenIds) external returns (uint256) {
    uint256 claimed = 0;
    address msgSender = _msgSender();

    for (uint i = 0; i < tokenIds.length; i++) {
      uint256 tokenId = tokenIds[i];
      require(tokenId.isTokenValid(), "malformed token");
      require(tokenId.tokenVersion() > 0, "invalid token version");
      require(ownerOf(tokenId) == msgSender, "only token holder can claim");

      // compute and add accumulated coins
      uint256 toClaim = accumulated(tokenId);
      claimed += toClaim;
      _lastClaimTimestamp[tokenId] = block.timestamp;
    }

    require(claimed > 0, "nothing to claim");

    // transfer from this contract (claim pool) to msg sender. This will revert
    // if this contract does not have enough BVAL to transfer
    _bvalTokenContract.transfer(msgSender, claimed);
    return claimed;
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

  // open zep hook called on all transfers (including burn/mint)
  function _beforeTokenTransfer(address from, address to, uint256 tokenId) override internal virtual {
    // on all tranfers / burns besides mint
    if (from != address(0)) {
      delete _tokenLockExpiresAt[tokenId];
    }

    // on burn
    if (to == address(0)) {
      delete _tokenStates[tokenId];
      delete _lastClaimTimestamp[tokenId];
    }

    super._beforeTokenTransfer(from, to, tokenId);
  }

}
