// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./@openzeppelin/AccessControlEnumerable.sol";
import "./@openzeppelin/ERC20.sol";

// a basic ERC20 token with some RBAC functionality to keep future iteration
// open while still allowing me progressively add more delegated trust to the
// system
contract BVAL20 is AccessControlEnumerable, ERC20 {

  string private constant NAME = "@bvalosek Token";
  string private constant SYMBOL = "BVAL";

  // grants ability to mint $BVAL
  bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

  // grants ability to grant MINTER_ROLE.
  bytes32 public constant MINTER_ADMIN_ROLE = keccak256("MINTER_ADMIN_ROLE");

  // grants ability to move $BVAL w/o allowances
  bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");

  // grants ability to grant OPERATOR_ROLE
  bytes32 public constant OPERATOR_ADMIN_ROLE = keccak256("OPERATOR_ADMIN_ROLE");

  constructor() ERC20(NAME, SYMBOL) {
    address msgSender = _msgSender();

    // only existing admins can add new admins
    _setRoleAdmin(MINTER_ADMIN_ROLE, MINTER_ADMIN_ROLE);
    _setRoleAdmin(OPERATOR_ADMIN_ROLE, OPERATOR_ADMIN_ROLE);

    // specific admin role for each actual role
    _setRoleAdmin(MINTER_ROLE, MINTER_ADMIN_ROLE);
    _setRoleAdmin(OPERATOR_ROLE, OPERATOR_ADMIN_ROLE);

    // contract deployer starts with ability to admin both roles and ability to mint
    _setupRole(MINTER_ADMIN_ROLE, msgSender);
    _setupRole(OPERATOR_ADMIN_ROLE, msgSender);
    _setupRole(MINTER_ROLE, msgSender);
  }

  // ---
  // minting
  // ---

  // mints tokens into the contract before transfer them to provided account
  // parameter
  function mintTo(address account, uint256 amount) external {
    require(hasRole(MINTER_ROLE, _msgSender()), "requires MINTER_ROLE");

    // mint tokens directly into the contract
    _mint(address(this), amount);

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
      // JIT approve msgSender to send amount of sender's tokens. This will
      // actually wipe out any existing allowance for msgSender after this call
      // since we are resetting it, thats okay since this only happens when
      // msgSender is an operator and the allowances aren't needed so long the
      // operator role is a "a thing"
      _approve(sender, msgSender, amount);
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

}
