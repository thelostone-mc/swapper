// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {SwapperSetup} from '../setup/Swapper.t.sol';

contract SwapperProperties is SwapperSetup {
  function property_swapperIsInitialized() external view {
    assert(address(_erc20ToErc20TargetContract.DEPOSITED_TOKEN()) != address(0));
    assert(address(_erc20ToErc20TargetContract.SWAPPED_TOKEN()) != address(0));

    assert(address(_erc20ToNativeTargetContract.DEPOSITED_TOKEN()) != address(0));
    assert(address(_erc20ToNativeTargetContract.SWAPPED_TOKEN()) == address(0));
  }
}
