// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./@openzeppelin/AccessControl.sol";
import "./@openzeppelin/ERC20.sol";

contract BVAL20 is AccessControl, ERC20 {

  uint private constant ONE_DAY =  60 * 60 * 24;
  uint private constant ONE_YEAR = ONE_DAY * 365;
  string private constant NAME = "@bvalosek Token";
  string private constant SYMBOL = "BVAL";

  bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
  bytes32 public constant DEADMAN_ROLE = keccak256("DEADMAN_ROLE");

  // timestamp after which minting is no longer possible
  uint private _deadmanTimestamp;

  constructor() ERC20(NAME, SYMBOL) {
    _deadmanTimestamp = block.timestamp + ONE_YEAR;
    _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
    _setupRole(MINTER_ROLE, _msgSender());
    _setupRole(DEADMAN_ROLE, _msgSender());
  }

  // ---
  // minting
  // ---

  function mintTo(address account, uint256 amount) external {
    require(hasRole(MINTER_ROLE, _msgSender()), "requires MINTER_ROLE");
    _mint(address(this), amount);
    transfer(account, amount);
  }

  // ---
  // Burnable implementation
  //

  // burn msg sender's coins
  function burn (uint256 amount) external {
    _burn(_msgSender(), amount);
  }

  // ---
  // deadman switch
  // ---

  // keep alive
  function pingDeadmanSwitch() public stillAlive {
    require(hasRole(DEADMAN_ROLE, _msgSender()), "requires DEADMAN_ROLE");
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

}
