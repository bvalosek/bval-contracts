// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./@openzeppelin/Strings.sol";
import "./@openzeppelin/Ownable.sol";
import "./@openzeppelin/ERC721-MODIFIED.sol";
// import "./@openzeppelin/IERC721Metadata.sol";

import "./interfaces/IOpenSeaContractURI.sol";
import "./interfaces/IRaribleRoyalties.sol";
import "./interfaces/IERC2981.sol";
import "./interfaces/ITokenMetadata.sol";
// import "./interfaces/ITokenState.sol";

import "./Sequenced.sol";
import "./TokenID.sol";
// import "./BVAL20.sol";

contract BVAL721 is
  // openzep bases
  Ownable,
  ERC721,

  // my additional bases
  Sequenced,

  // standard interfaces
  IERC721Metadata,

  // my interfaces
  ITokenMetadata,

  // marketplace interfaces
  IRaribleRoyalties,
  IOpenSeaContractURI,
  IERC2981

  {

  using Strings for uint256;
  using TokenID for uint256;

  // immutable contract properties -- hardcoding since we cant use immutable
  // strings yet
  uint16 private constant _collectionVersion = 1;
  string private constant _name = "@bvalosek Collection";
  string private constant _symbol = "BVAL-NFT";
  uint16 private constant _feeBps = 1000; // 10%

  // modifiable contract properties
  string private _baseURI;

  // individual token state
  mapping (uint256 => uint256) private _tokenStates;

  // token URI override
  mapping (uint256 => string) private _tokenURIs;

  // constructor options
  struct ContractOptions {
    string description;
    string data;
    string baseURI;
  }

  constructor (ContractOptions memory options) {
    _baseURI = options.baseURI;
    emit CollectionMetadata(_name, options.description, options.data);
  }

  // ---
  // ERC-721 basics
  // ---

  // mint a new token for the contract owner and emit metadata as an event
  function mint(
    uint256 tokenId,
    string memory name_,
    string memory description_,
    string memory data_) external onlyOwner {
      require(tokenId.isTokenValid() == true, "malformed token");
      require(tokenId.tokenVersion() > 0, "invalid token version");
      require(getSequenceState(tokenId.tokenSequenceNumber()) == SequenceState.STARTED, "sequence is not active");

      _mint(owner(), tokenId);
      emit TokenMetadata(tokenId, name_, description_, data_);

      // rarible-style royalty info
      address[] memory recipients = new address[](1);
      recipients[0] = owner();
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
    string memory data_) override external onlyOwner {
      _startSequence(number, name_, description_, data_);
  }

  // complete the sequence
  function completeSequence(uint16 number) override external onlyOwner {
    _completeSequence(number);
  }

  // ---
  // Token State
  // ---


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

  // ---
  // Metadata
  // ---

  // collection name
  function name() external pure override returns (string memory) {
    return _name;
  }

  // collection symbol
  function symbol() external pure override returns (string memory) {
    return _symbol;
  }

  // token metadata URI
  function tokenURI(uint256 tokenId) external view override returns (string memory) {
    require(_exists(tokenId), "invalid token");

    // if an override was set for this token
    string memory uri = _tokenURIs[tokenId];
    if (bytes(uri).length > 0) {
      return uri;
    }

    return string(abi.encodePacked(
      _baseURI,
      "/api/metadata/token/",
      tokenId.toString()
    ));
  }

  // set a token URI override
  function setTokenURI(uint256 tokenId, string memory uri) external onlyOwner {
    require(_exists(tokenId), "invalid token");
    _tokenURIs[tokenId] = uri;
  }

  // contract metadata URI (opensea)
  function contractURI() external view override returns (string memory) {
    return string(abi.encodePacked(
      _baseURI,
      "/api/metadata/collection/",
      uint256(_collectionVersion).toString()
    ));
  }

  // swap out base URI
  function setBaseURI(string calldata uri) external onlyOwner {
    _baseURI = uri;
  }

  // ---
  // rarible
  // ---

  // rarible royalties
  function getFeeRecipients(uint256 tokenId) override public view returns (address payable[] memory) {
    require(_exists(tokenId), "invalid token");
    address payable[] memory ret = new address payable[](1);
    ret[0] = payable(owner());
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
    return (owner(), uint256(_feeBps) * 100);
  }


  // ---
  // introspection
  // ---

  // ERC165
  function supportsInterface(bytes4 interfaceId) public view virtual override (IERC165, ERC721) returns (bool) {
    return interfaceId == type(IERC721Metadata).interfaceId
      // || interfaceId == type(ITokenState).interfaceId
      || interfaceId == type(IERC2981).interfaceId
      || interfaceId == type(IOpenSeaContractURI).interfaceId
      || interfaceId == type(IRaribleRoyalties).interfaceId
      || super.supportsInterface(interfaceId);
  }

}
