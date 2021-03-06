// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./@openzeppelin/Strings.sol";
import "./@openzeppelin/AccessControlEnumerable.sol";
import "./@openzeppelin/ERC721Enumerable.sol";

import "./interfaces/IOpenSeaContractURI.sol";
import "./interfaces/IRaribleRoyalties.sol";
import "./interfaces/IERC2981.sol";
import "./interfaces/ITokenMetadata.sol";

import "./Sequenced.sol";
import "./TokenID.sol";

// A general enumerable/metadata-enabled 721 contract with several extra
// features added:
// - emitting token metadata via event logs
// - "sequences"
// - royality support (rarible, EIP2981)
// - RBAC for minting
contract Base721 is
  // openzep bases
  AccessControlEnumerable,
  ERC721Enumerable,

  // my additional bases
  Sequenced,

  // my interfaces
  ITokenMetadata,

  // marketplace interfaces
  IRaribleRoyalties,
  IOpenSeaContractURI,
  IERC2981

  {

  using Strings for uint256;
  using TokenID for uint256;

  // royality fee BPS (1/100ths of a percent, eg 1000 = 10%)
  uint16 private immutable _feeBps;

  // able to mint and manage sequences
  bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

  // base URI of token gateway
  string private _gatewayURI;

  // address to send royalties to
  address private _royaltyRecipient;

  // individual token state
  mapping (uint256 => uint256) private _tokenStates;

  // mapping from a token ID to when its state lock expires
  mapping (uint256 => uint) private _tokenLockExpiresAt;

  // token URI override
  mapping (uint256 => string) private _tokenURIs;

  // constructor options
  struct ContractOptions {
    string symbol;
    string name;
    string description;
    string data;
    string baseURI;
    uint16 feeBps;
  }

  constructor (ContractOptions memory options) ERC721(options.name, options.symbol) {
    address msgSender = _msgSender();

    _setupRole(DEFAULT_ADMIN_ROLE, msgSender);
    _setupRole(MINTER_ROLE, msgSender);

    _royaltyRecipient = msgSender;
    _gatewayURI = options.baseURI;
    _feeBps = options.feeBps;

    emit CollectionMetadata(options.name, options.description, options.data);
  }

  // ---
  // Admin
  // ---

  // set a token URI override
  function setTokenURI(uint256 tokenId, string memory uri) external {
    require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "requires DEFAULT_ADMIN_ROLE");
    require(_exists(tokenId), "invalid token");
    _tokenURIs[tokenId] = uri;
  }

  // swap out base URI
  function setBaseURI(string calldata uri) external {
    require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "requires DEFAULT_ADMIN_ROLE");
    _gatewayURI = uri;
  }

  // set address that royalties are sent to
  function setRoyaltyRecipient(address recipient) external {
    require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "requires DEFAULT_ADMIN_ROLE");
    _royaltyRecipient = recipient;
  }

  // ---
  // ERC-721 basics
  // ---

  // mint a new token for the contract owner and emit metadata as an event
  function mint(
    uint256 tokenId,
    string memory name_,
    string memory description_,
    string memory data_) external {
      address msgSender = _msgSender();
      require(hasRole(MINTER_ROLE, msgSender), "requires MINTER_ROLE");
      require(tokenId.isTokenValid() == true, "malformed token");
      require(tokenId.tokenVersion() > 0, "invalid token version");
      require(getSequenceState(tokenId.tokenSequenceNumber()) == SequenceState.STARTED, "sequence is not active");

      _mint(msgSender, tokenId);
      emit TokenMetadata(tokenId, name_, description_, data_);

      // rarible-style royalty info
      address[] memory recipients = new address[](1);
      recipients[0] = _royaltyRecipient;
      emit SecondarySaleFees(tokenId, recipients, getFeeBps(tokenId));
  }

  // destroy a token
  // msg.sender MUST be approved or owner
  function burn(uint256 tokenId) external {
    require(_isApprovedOrOwner(_msgSender(), tokenId), "not token owner");
    _burn(tokenId);
    delete _tokenURIs[tokenId];
    delete _tokenStates[tokenId];
  }

  // ---
  // Sequences
  // ---

  // start sequence
  function startSequence(
    uint16 number,
    string memory name_,
    string memory description_,
    string memory data_) override external {
      require(hasRole(MINTER_ROLE, _msgSender()), "requires MINTER_ROLE");
      _startSequence(number, name_, description_, data_);
  }

  // complete the sequence
  function completeSequence(uint16 number) override external {
    require(hasRole(MINTER_ROLE, _msgSender()), "requires MINTER_ROLE");
    _completeSequence(number);
  }

  // ---
  // Metadata
  // ---

  // token metadata URI
  function tokenURI(uint256 tokenId) public view override returns (string memory) {
    require(_exists(tokenId), "invalid token");

    // if an override was set for this token
    string memory uri = _tokenURIs[tokenId];
    if (bytes(uri).length > 0) {
      return uri;
    }

    return string(abi.encodePacked(
      _gatewayURI,
      "/api/metadata/token/",
      tokenId.toString()
    ));
  }


  // contract metadata URI (opensea)
  function contractURI() external view override returns (string memory) {
    return string(abi.encodePacked(
      _gatewayURI,
      "/api/metadata/collection"
    ));
  }

  // ---
  // rarible
  // ---

  // rarible royalties
  function getFeeRecipients(uint256 tokenId) override public view returns (address payable[] memory) {
    require(_exists(tokenId), "invalid token");
    address payable[] memory ret = new address payable[](1);
    ret[0] = payable(_royaltyRecipient);
    return ret;
  }

  // rarible royalties
  function getFeeBps(uint256 tokenId) override public view returns (uint[] memory) {
    require(_exists(tokenId), "invalid token");
    uint256[] memory ret = new uint[](1);
    ret[0] = uint(_feeBps);
    return ret;
  }

  // ---
  // More royalities (mintable?) / EIP-2981
  // ---

  function royaltyInfo(uint256 tokenId) override external view returns (address receiver, uint256 amount) {
    require(_exists(tokenId), "invalid token");
    return (_royaltyRecipient, uint256(_feeBps) * 100);
  }

  // ---
  // introspection
  // ---

  // ERC165
  function supportsInterface(bytes4 interfaceId) public view virtual override (IERC165, ERC721Enumerable, AccessControlEnumerable) returns (bool) {
    return interfaceId == type(IERC721Metadata).interfaceId
      || interfaceId == type(IERC2981).interfaceId
      || interfaceId == type(IOpenSeaContractURI).interfaceId
      || interfaceId == type(IRaribleRoyalties).interfaceId
      || super.supportsInterface(interfaceId);
  }

}
