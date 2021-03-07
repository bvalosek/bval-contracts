// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./@openzeppelin/IERC20.sol";

import "./Sequenced721.sol";
import "./TokenID.sol";
import "./interfaces/ITokenState.sol";

contract BVAL721 is Sequenced721, ITokenState {
  using TokenID for uint256;

  // grants ability to set state for all tokens
  bytes32 public constant MUTATOR_ROLE = keccak256("MUTATOR_ROLE");

  // hard-coded contract info
  string private constant NAME = "@bvalosek Collection";
  string private constant DESCRIPTION = "Dynamic and interactive NFTs featuring the abstract digital art of Brandon Valosek";
  string private constant DATA = "QmTC2N4rXQfnPmHUQEgLPYtfFHryoxWQEDsrTWFg8RffTk";
  string private constant SYMBOL = "BVAL-NFT";
  uint16 private constant FEE_BPS = 1000;

  // w/ openzep RBAC, use zero address as flag to indicate all senders have access
  address private constant EVERYONE = address(0);

  uint private constant ONE_DAY =  60 * 60 * 24;

  // reference to the ERC20 $BVAL
  IERC20 private immutable _bvalTokenContract;

  // base BVAL/day accumulation rate before token yield multiplier is applied
  uint256 private _baseDailyRate = 10 ** 18;

  // the base burn amount when submitting a state change for a token with a burn amount
  uint256 private _baseBurnAmount = 10 ** 18;

  // individual token state
  mapping (uint256 => uint256) private _tokenStates;

  // mapping from a token ID to when its state lock expires
  mapping (uint256 => uint) private _tokenLockExpiresAt;

  // mapping from a token ID to the last claim timestamp
  mapping (uint256 => uint) private _lastClaimTimestamp;

  // mapping from a sequence number to registered sequence engine
  mapping (uint16 => ISequenceEngine) private _engines;

  constructor (string memory baseURI, IERC20 bvalTokenContract) Sequenced721(ContractOptions({
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
  // Admin
  // ---

  // set the base daily rate accumulation rate
  function setBaseDailyRate(uint256 rate) external {
    require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "requires DEFAULT_ADMIN_ROLE");
    _baseDailyRate = rate;
  }

  // set the base burn amount
  function setBaseBurnAmount(uint256 amount) external {
    require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "requires DEFAULT_ADMIN_ROLE");
    _baseBurnAmount = amount;
  }

  // set an engine for a given sequence
  function registerEngine(uint16 sequenceNumber, ISequenceEngine engine) external {
    require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "requires DEFAULT_ADMIN_ROLE");
    require(_engines[sequenceNumber] == ISequenceEngine(address(0)), "engine already registered");
    _engines[sequenceNumber] = engine;
  }

  // amount of BVAL consumed on state change when NFT burn multiplier = 1
  function baseBurnAmount() external view returns (uint256) {
    return _baseBurnAmount;
  }

  // amount of BVAl generated daily when NFT yield multiplier = 1
  function baseDailyRate() external view returns (uint256) {
    return _baseDailyRate;
  }

  // get the sequence engine contract for a sequence
  function getEngine(uint16 sequenceNumber) external view returns (ISequenceEngine) {
    return _engines[sequenceNumber];
  }

  // ---
  // Token Locking
  // ---

  // lock a set of tokens for 24 hours
  function lockTokens(uint256[] calldata tokenIds) external {
    uint expiresAt = block.timestamp + ONE_DAY;
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

  // ---
  // Token State
  // --

  // set the state of a token
  function setTokenState(SetTokenState[] calldata entries) override external {
    address msgSender = _msgSender();
    address self = address(this);
    uint timestamp = block.timestamp;
    bool isMutator = hasRole(MUTATOR_ROLE, msgSender);

    for (uint i = 0; i < entries.length; i++) {
      uint256 tokenId = entries[i].tokenId;
      uint256 input = entries[i].input;
      uint256 state = _tokenStates[tokenId];
      uint256 next = input;
      address owner = ownerOf(tokenId);
      require(isMutator || owner == msgSender, "not token owner");
      require(_tokenLockExpiresAt[tokenId] <= timestamp, "token is locked");

      // if there is a registered sequence engine, process the state change
      // there and use the return value as the next stage
      ISequenceEngine engine = _engines[tokenId.tokenSequenceNumber()];
      if (engine != ISequenceEngine(address(0))) {
        next = engine.processStateChange(tokenId, owner, input, state);
      }

      // transfer any burn amount back to the claim pool
      uint256 burn = uint256(tokenId.tokenBurnMultiplier()) * _baseBurnAmount;
      if (burn > 0) {
        _bvalTokenContract.transferFrom(msgSender, self, burn);
      }

      _tokenStates[tokenId] = next;
      emit TokenState(tokenId, input, next);
    }
  }

  // get the current token state
  function getTokenState(uint256 tokenId) override external view returns (uint256) {
    require(_exists(tokenId), "invalid token");
    return _tokenStates[tokenId];
  }

  // ---
  // $BVAL
  // --

  // determine the accumulated BVAL for a given token
  function accumulated(uint256 tokenId) public view returns (uint256) {
    require(_exists(tokenId), "invalid token");
    require(tokenId.tokenVersion() > 0, "invalid token version");

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
    uint timestamp = block.timestamp;

    for (uint i = 0; i < tokenIds.length; i++) {
      uint256 tokenId = tokenIds[i];
      require(ownerOf(tokenId) == msgSender, "not token owner");
      require(_tokenLockExpiresAt[tokenId] <= timestamp, "token is locked");

      // compute and add accumulated tokens
      claimed += accumulated(tokenId);
      _lastClaimTimestamp[tokenId] = timestamp;
    }

    require(claimed > 0, "nothing to claim");

    // transfer from this contract (claim pool) to msg sender. This will revert
    // if this contract does not have enough BVAL to transfer
    _bvalTokenContract.transfer(msgSender, claimed);
    return claimed;
  }

  // ---
  // openzep hooks
  // --

  // open zep hook called on all transfers (including burn/mint)
  function _beforeTokenTransfer(address from, address to, uint256 tokenId) override internal virtual {

    // cleanup on burn
    if (to == address(0)) {
      delete _tokenStates[tokenId];
      delete _lastClaimTimestamp[tokenId];
      delete _tokenLockExpiresAt[tokenId];
    }

    super._beforeTokenTransfer(from, to, tokenId);
  }

}
