// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./@openzeppelin/Ownable.sol";
import "./@openzeppelin/ERC20.sol";

contract BVAL20 is Ownable, ERC20 {

  uint private constant ONE_DAY =  60 * 60 * 24;
  uint private constant ONE_YEAR = ONE_DAY * 365;
  string private constant NAME = "@bvalosek Token";
  string private constant SYMBOL = "BVAL";

  // timestamp after which minting is no longer possible
  uint private _deadmanTimestamp;

  constructor() ERC20(NAME, SYMBOL) {
    _deadmanTimestamp = block.timestamp + ONE_YEAR;
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

}
