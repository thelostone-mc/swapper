// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {MockERC20 as ForgeMockERC20} from 'forge-std/mocks/MockERC20.sol';

contract MockERC20 is ForgeMockERC20 {
  function mint(address to, uint256 amount) external {
    _mint(to, amount);
  }

  function burnFrom(address from, uint256 amount) external {
    _burn(from, amount);
  }
}
