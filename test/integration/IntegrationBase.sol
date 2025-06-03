// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {ISwapper, SwapperV1} from 'contracts/SwapperV1.sol';
import {Test} from 'forge-std/Test.sol';
import {IERC20} from 'forge-std/interfaces/IERC20.sol';

contract IntegrationBase is Test {
  uint256 internal constant _FORK_BLOCK = 18_920_905;

  address internal _owner = makeAddr('owner');

  IERC20 internal _dai = IERC20(0x6B175474E89094C44Da98b954EedeAC495271d0F);

  // DAI whales
  address internal _bob = 0xFd546293a729fE1A05D249Ad4F2CA984082F889e;
  address internal _alice = 0xc08a8a9f809107c5A7Be6d90e315e4012c99F39a;

  ISwapper internal _swapper;

  function setUp() public {
    vm.createSelectFork(vm.rpcUrl('mainnet'), _FORK_BLOCK);
    vm.prank(_owner);
    _swapper = new SwapperV1(address(_dai), address(0));
  }
}
