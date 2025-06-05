// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {IERC20} from '@openzeppelin/token/ERC20/IERC20.sol';
import {ISwapperV2} from 'contracts/SwapperV2.sol';
import {IntegrationBase} from 'test/integration/IntegrationBase.sol';

contract IntegrationSwapperV2 is IntegrationBase {
  function test_DepositSwapDepositWithdraws_ETHtoDAI() public {
    // Bob deposits 1 ether before swap
    vm.deal(_bob, 1 ether);
    vm.prank(_bob);
    _swapperV2.deposit{value: 1 ether}(1 ether);

    // Owner performs swap (ETH -> DAI)
    vm.prank(_owner);
    _swapperV2.swap();

    // Bob deposits another 1 ether after swap
    vm.deal(_bob, 1 ether);
    vm.prank(_bob);
    _swapperV2.deposit{value: 1 ether}(1 ether);

    // Bob tries to withdraw deposit (should only withdraw the second deposit, as the first was swapped)
    vm.startPrank(_bob);
    uint256 bobEthBefore = _bob.balance;
    _swapperV2.withdrawDeposit();
    uint256 bobEthAfter = _bob.balance;
    vm.stopPrank();

    // Bob should have received 1 ether back (the second deposit)
    assertEq(bobEthAfter - bobEthBefore, 1 ether);

    // Bob tries to withdraw swapped tokens (should only be able to withdraw the first deposit's share in DAI)
    IERC20 dai = IERC20(_swapperV2.SWAPPED_TOKEN());
    uint256 bobDaiBefore = dai.balanceOf(_bob);

    vm.startPrank(_bob);
    _swapperV2.withdraw();
    vm.stopPrank();

    uint256 bobDaiAfter = dai.balanceOf(_bob);

    // Bob should have received some DAI (from the first deposit)
    assertGt(bobDaiAfter - bobDaiBefore, 0);

    // Check that Bob's deposits are now empty
    ISwapperV2.Deposits[] memory deposits = _swapperV2.getDeposits(_bob);
    assertEq(deposits.length, 0);
  }
}
