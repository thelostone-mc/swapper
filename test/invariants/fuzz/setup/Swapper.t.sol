// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import {SwapperV1} from 'contracts/SwapperV1.sol';

import {CommonBase} from 'forge-std/Base.sol';
import {MockERC20} from 'test/mocks/MockERC20.sol';

contract SwapperSetup is CommonBase {
  SwapperV1 internal _erc20ToErc20TargetContract;
  SwapperV1 internal _erc20ToNativeTargetContract;
  MockERC20 internal _wunder;
  MockERC20 internal _kinder;

  constructor() {
    _wunder = new MockERC20();
    _wunder.initialize('WUNDER', 'WUN', 18);
    _kinder = new MockERC20();
    _kinder.initialize('KINDER', 'KIN', 18);

    _erc20ToErc20TargetContract = new SwapperV1(address(_wunder), address(_kinder));
    _erc20ToNativeTargetContract = new SwapperV1(address(_wunder), address(0));
  }
}
