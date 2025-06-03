// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {IntegrationBase} from 'test/integration/IntegrationBase.sol';

contract IntegrationSwapper is IntegrationBase {
  function test_Swap() public {
    // Deposit tokens
    vm.startPrank(_bob);
    _dai.approve(address(_swapper), 1e18);
    _swapper.deposit(1e18);
    vm.stopPrank();

    vm.startPrank(_alice);
    _dai.approve(address(_swapper), 2e18);
    _swapper.deposit(2e18);
    vm.stopPrank();

    // Check token balance on contract
    assertEq(_dai.balanceOf(address(_swapper)), 3e18);

    assertEq(_dai.balanceOf(address(_owner)), 0);
    vm.deal(_owner, 3e18);

    // Swap tokens
    vm.prank(_owner);
    _swapper.swap{value: 3e18}();

    // Check token and native token balance
    assertEq(_owner.balance, 0);
    assertEq(address(_swapper).balance, 3e18);
    assertEq(_dai.balanceOf(address(_owner)), 3e18);
    assertEq(_dai.balanceOf(address(_swapper)), 0);

    uint256 _bobBalanceBefore = _bob.balance;
    uint256 _aliceBalanceBefore = _alice.balance;

    // Withdraw tokens
    vm.prank(_bob);
    _swapper.withdraw();

    // Check token balance on contract
    assertEq(address(_swapper).balance, 2e18);
    assertEq(_bob.balance, _bobBalanceBefore + 1e18);

    vm.prank(_alice);
    _swapper.withdraw();

    // Check token balance on contract
    assertEq(address(_swapper).balance, 0);
    assertEq(_alice.balance, _aliceBalanceBefore + 2e18);
  }
}
