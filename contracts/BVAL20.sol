// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./@openzeppelin/AccessControlEnumerable.sol";
import "./@openzeppelin/ERC20.sol";

// a basic ERC20 coin with a deadmans switch and some RBAC functionality to keep
// future iteration open while still allowing me progressively add more
// delegated trust to the system
contract BVAL20 is AccessControlEnumerable, ERC20 {

  uint private constant ONE_DAY =  60 * 60 * 24;
  uint private constant ONE_YEAR = ONE_DAY * 365;
  string private constant NAME = "@bvalosek Token";
  string private constant SYMBOL = "BVAL";

  // grants ability to mint $BVAL
  bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

  // grants ability to move $BVAL w/o allowances
  bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");

  // grants able to ping deadmans switch
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
    require(stillAlive(), "deadman's switch has been tripped");
    require(hasRole(MINTER_ROLE, _msgSender()), "requires MINTER_ROLE");
    address self = address(this);

    // mint tokens into the contract
    _mint(self, amount);

    // call transfer as "this" in order to transfer FROM the contract TO
    // account. Calling w/o "this" would attempt to tranfer FROM msgSender
    this.transfer(account, amount);
  }

  // ---
  // ERC20 modifications
  // ---

  // patch transferFrom to allow JIT-allowance when msgSender has the OPERATOR
  // role. this is a bit overreaching but allows for better UX and avoids having
  // to make two trx for anything I build that manages $BVAL to start. this can
  // be disabled in the future by removing all granted OPERATOR roles
  function transferFrom(address sender, address recipient, uint256 amount) override public returns (bool) {
    address msgSender = _msgSender();
    if (hasRole(OPERATOR_ROLE, msgSender)) {
      increaseAllowance(msgSender, amount);
    }
    return super.transferFrom(sender, recipient, amount);
  }

  // ---
  // Burnable implementation
  // ---

  // burn msg sender's coins
  function burn (uint256 amount) external {
    _burn(_msgSender(), amount);
  }

  // ---
  // deadman switch
  // ---

  // keep alive
  function pingDeadmanSwitch() public {
    require(stillAlive(), "deadmans switch has been tripped");
    require(hasRole(DEADMAN_ROLE, _msgSender()), "requires DEADMAN_ROLE");
    _deadmanTimestamp = block.timestamp + ONE_YEAR;
  }

  // get timestamp
  function deadmanTimestamp() public view returns (uint) {
    return _deadmanTimestamp;
  }

  // restrict a function call to only allowed when alive
  function stillAlive() public view returns (bool) {
    return _deadmanTimestamp > block.timestamp;
  }

}
