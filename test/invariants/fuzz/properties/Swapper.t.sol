// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {SwapperSetup} from '../setup/Swapper.t.sol';

contract SwapperProperties is SwapperSetup {
  function property_swapperIsInitialized() external view {
    assert(address(_Erc20ToErc20targetContract.DEPOSITED_TOKEN()) != address(0));
    assert(address(_Erc20ToErc20targetContract.SWAPPED_TOKEN()) != address(0));

    assert(address(_Erc20ToNativeTargetContract.DEPOSITED_TOKEN()) != address(0));
    assert(address(_Erc20ToNativeTargetContract.SWAPPED_TOKEN()) == address(0));
  }
}
