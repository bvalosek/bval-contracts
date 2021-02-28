// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./@openzeppelin/Ownable.sol";
import "./@openzeppelin/ERC20-MODIFIED.sol";
import "./@openzeppelin/IERC721.sol";
import "./TokenID.sol";
import "./interfaces/IERC20Burnable.sol";

contract BVAL20 is Ownable, ERC20, IERC20Burnable {
  using TokenID for uint256;

  uint internal constant ONE_DAY =  60 * 60 * 24;
  uint internal constant ONE_YEAR = 60 * 60 * 24 * 365;

  // making these constants to avoid paying storage gas (no immutable strings yet)
  string private constant _name = "@bvalosek Coin";
  string private constant _symbol = "BVAL";

  // the collection version -> contract address mappings
  mapping (uint16 => IERC721) private _nftContracts;

  // used to determine if a contract is in the allow list (bypasses allowance check)
  mapping (address => bool) private _allowedOperators;

  // mapping from a token ID to the last claim timestamp
  mapping (uint256 => uint) private _lastClaims;

  // timestamp after which emission stops
  uint private _deadmanTimestamp;

  constructor() {
    _deadmanTimestamp = block.timestamp + ONE_YEAR;
  }

  // ---
  // Burnable implementation
  //

  // burn msg sender's coins
  function burn (uint256 amount) override external {
    _burn(_msgSender(), amount);
  }

  // ---
  // deadman switch
  // ---

  // keep alive
  function pingDeadmanSwitch() public onlyOwner stillAlive {
    _deadmanTimestamp = block.timestamp + ONE_YEAR;
  }

  // get timestamp
  function deadmanTimestamp() public view returns (uint) {
    return _deadmanTimestamp;
  }

  // restrict a function call to only allowed when alive
  modifier stillAlive() {
    require(_deadmanTimestamp > block.timestamp, "deadman switch has been tripped");
    _;
  }

  // ---
  // metadata
  // ---

  // coin name
  function name() public pure returns (string memory) {
    return _name;
  }

  // coin symbol
  function symbol() public pure returns (string memory) {
    return _symbol;
  }

  // ---
  // management
  // ---

  // set the mapping from a collection version -> contract address
  // can only be set once for a given collection
  function setContract(uint16 version, IERC721 contractAddress) external onlyOwner stillAlive {
    require(_nftContracts[version] == IERC721(address(0)), "collection version already set");
    _nftContracts[version] = contractAddress;
    _allowedOperators[address(contractAddress)] = true;
  }

  // get the contract for a specific version
  function getContract(uint16 version) public view returns (IERC721) {
    require(_nftContracts[version] != IERC721(address(0)), "no contract set");
    return IERC721(_nftContracts[version]);
  }

  // ---
  // bval patched
  // ---

  // if msg sender is a BVAL NFT contract, bypass allowance check, otherwise
  // delegate to base ERC20 implementation
  function transferFrom(address sender, address recipient, uint256 amount) public virtual override (ERC20, IERC20) returns (bool) {
    // This allows $BVAL transfers executed by a BVAL-NFT contract to not force
    // the holder to call approve() first
    if (_allowedOperators[_msgSender()]) {
      _transfer(sender, recipient, amount);
      return true;
    }

    return super.transferFrom(sender, recipient, amount);
  }

  // ---
  // minting
  // ---

  // determine total bval accumulated for a specific tokenId
  function accumulated(uint256 tokenId) public view returns (uint256) {
    // determine emission window, which is either mint -> now or mint -> deadman
    // time, which ever is shorter
    uint emissionStart = tokenId.tokenMintTimestamp();
    uint emissionStop = _deadmanTimestamp < block.timestamp ? _deadmanTimestamp : block.timestamp;

    // determine when we should claim from. either mint date if no claims have
    // happened, or its the last claim
    uint lastClaim = _lastClaims[tokenId];
    uint claimFrom = lastClaim != 0 ? lastClaim : emissionStart;

    // determine period in seconds to claim for, 0 if negative (mint in future)
    uint period = emissionStop > claimFrom ? emissionStop - claimFrom : 0;

    // compute how much $BVAL to issue based on emission rate
    uint256 toClaim = period * tokenId.tokenEmissionRate() * (10 ** decimals()) / ONE_DAY;
    return toClaim;
  }

  // claim $BVAL for multiple NFTs at once
  function claim(uint256[] memory tokenIds) external returns (uint256) {
    uint256 claimed = 0;

    for (uint i = 0; i < tokenIds.length; i++) {
      // resolve relevant NFT contract to assert msg sender is token holder
      uint256 tokenId = tokenIds[i];
      IERC721 collection = getContract(tokenId.tokenCollectionVersion());
      require(collection.ownerOf(tokenId) == _msgSender(), "only token holder can claim");

      // compute and add accumulated coins
      uint256 toClaim = accumulated(tokenId);
      claimed += toClaim;
      _lastClaims[tokenId] = block.timestamp;
    }

    // mint new coins for the caller5
    require(claimed > 0, "nothing to claim");
    _mint(_msgSender(), claimed);
    return claimed;
  }

}
