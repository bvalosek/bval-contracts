// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../@openzeppelin/IERC20.sol";

// ERC-20 + burn method
interface IERC20Burnable is IERC20 {

  // destroy msg sender's coins
  function burn(uint256 amount) external;

}
