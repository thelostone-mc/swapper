// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Test} from 'forge-std/Test.sol';
import 'forge-std/console.sol';

import {Ownable} from '@openzeppelin/access/Ownable.sol';
import {IERC20} from 'forge-std/interfaces/IERC20.sol';
import {ISwapper, SwapperV1} from 'src/contracts/SwapperV1.sol';

import {MockERC20} from 'test/mocks/MockERC20.sol';

contract UnitSwapperV1 is Test {
  SwapperV1 public nativeToERC20Swapper;
  SwapperV1 public erc20ToNativeSwapper;
  SwapperV1 public erc20ToErc20Swapper;

  MockERC20 public wunder;
  MockERC20 public kinder;

  address internal _owner = makeAddr('_owner');
  address internal _bob = makeAddr('_bob');
  address internal _alice = makeAddr('_alice');
  address internal _whale = makeAddr('_whale');

  function setUp() public {
    vm.startPrank(_owner);

    // Setup ERC20 tokens
    wunder = new MockERC20();
    wunder.initialize('WUNDER', 'WUN', 8);
    kinder = new MockERC20();
    kinder.initialize('KINDER', 'KIN', 8);

    // Setup Swapper Contracts
    nativeToERC20Swapper = new SwapperV1(address(0), address(wunder));
    erc20ToNativeSwapper = new SwapperV1(address(wunder), address(0));
    erc20ToErc20Swapper = new SwapperV1(address(wunder), address(kinder));

    vm.stopPrank();
  }

  function test_ConstructorWhenPassingValidTokens() public view {
    // it deploys
    assertEq(nativeToERC20Swapper.owner(), _owner);
    // it sets the deposited token
    assertEq(nativeToERC20Swapper.DEPOSITED_TOKEN(), address(0));
    // it sets the swapped token
    assertEq(nativeToERC20Swapper.SWAPPED_TOKEN(), address(wunder));
  }

  function test_ConstructorWhenPassingSameTokenForDepositedAndSwapped() public {
    // it reverts
    vm.expectRevert(ISwapper.Swapper_InvalidTokens.selector);
    new SwapperV1(address(wunder), address(wunder));
  }

  function test_DepositWhenPassingValidNativeTokenAmount() public {
    vm.deal(_bob, 1 ether);
    vm.startPrank(_bob);

    // it emits TokensDeposited
    vm.expectEmit(true, true, true, true);
    emit ISwapper.TokensDeposited(_bob, 1e18);

    nativeToERC20Swapper.deposit{value: 1 ether}(1e18);
    vm.stopPrank();

    // it deposits the amount to the contract
    ISwapper.SwapInfo memory swapInfo = nativeToERC20Swapper.userToSwapInfo(_bob);

    // it updates the deposit token amount
    assertEq(swapInfo.depositTokenAmount, 1e18);
    // it sets the hasWithdrawn flag to false
    assertEq(swapInfo.hasWithdrawn, false);

    // it updates the balance of the contract
    assertEq(address(nativeToERC20Swapper).balance, 1e18);
  }

  function test_DepositWhenPassingValidErc20TokenAmount() public {
    wunder.mint(_bob, 1e18);
    vm.startPrank(_bob);

    wunder.approve(address(erc20ToNativeSwapper), 1e18);

    // it emits TokensDeposited
    vm.expectEmit(true, true, true, true);
    emit ISwapper.TokensDeposited(_bob, 1e18);

    // it deposits the amount to the contract
    erc20ToNativeSwapper.deposit(1e18);

    vm.stopPrank();

    ISwapper.SwapInfo memory swapInfo = erc20ToNativeSwapper.userToSwapInfo(_bob);

    // it updates the deposit token amount
    assertEq(swapInfo.depositTokenAmount, 1e18);

    // it sets the hasWithdrawn flag to false
    assertEq(swapInfo.hasWithdrawn, false);

    // it updates the balance of the contract
    assertEq(wunder.balanceOf(address(erc20ToNativeSwapper)), 1e18);
  }

  function test_DepositWhenPassingAmountOf0() public {
    vm.expectRevert(ISwapper.Swapper_InvalidAmount.selector);
    vm.prank(_bob);
    // it reverts
    nativeToERC20Swapper.deposit{value: 0}(0);
  }

  function test_DepositWhenBalanceOfTheContractIsLessThanTheAmountSent() public {
    vm.deal(_bob, 1 ether);

    vm.expectRevert(ISwapper.Swapper_AmountMismatch.selector);
    vm.prank(_bob);
    nativeToERC20Swapper.deposit{value: 0.5 ether}(1e18);
  }

  function test_DepositWhenBalanceOfTheContractIsGreaterThanTheAmountSent() public {
    vm.deal(_bob, 1 ether);
    vm.expectRevert(ISwapper.Swapper_AmountMismatch.selector);

    vm.prank(_bob);
    nativeToERC20Swapper.deposit{value: 1 ether}(0.5 ether);
  }

  function test_DepositWhenDepositingMoreThanOnce() public {
    test_DepositWhenPassingValidNativeTokenAmount();

    vm.deal(_bob, 1 ether);

    vm.expectEmit(true, true, true, true);
    emit ISwapper.TokensDeposited(_bob, 1e18);

    vm.prank(_bob);
    nativeToERC20Swapper.deposit{value: 1 ether}(1e18);

    ISwapper.SwapInfo memory swapInfo = nativeToERC20Swapper.userToSwapInfo(_bob);

    assertEq(swapInfo.depositTokenAmount, 2e18);
    assertEq(swapInfo.hasWithdrawn, false);

    assertEq(address(nativeToERC20Swapper).balance, 2e18);
  }

  function test_DepositWhenCalledAfterSwap() public {
    test_SwapWhenSwappingToERC20TokensToTheContract();

    vm.deal(_bob, 1 ether);
    vm.expectRevert(ISwapper.Swapper_SwapAlreadyExecuted.selector);
    vm.prank(_bob);
    // it reverts
    nativeToERC20Swapper.deposit{value: 1 ether}(1e18);
  }

  function test_SwapWhenSwappingToERC20TokensToTheContract() public {
    test_DepositWhenPassingValidNativeTokenAmount();

    wunder.mint(_owner, 1e18);

    assertEq(wunder.balanceOf(_owner), 1e18);
    assertEq(wunder.balanceOf(address(nativeToERC20Swapper)), 0);

    vm.startPrank(_owner);
    wunder.approve(address(nativeToERC20Swapper), 1e18);

    // it emits TokensSwapped
    vm.expectEmit(true, true, true, true);
    emit ISwapper.TokensSwapped(1e18, 1e18);

    nativeToERC20Swapper.swap();
    vm.stopPrank();

    // it transfers the tokens to the _owner
    assertEq(wunder.balanceOf(address(nativeToERC20Swapper)), 1e18);
    assertEq(wunder.balanceOf(_owner), 0);

    // it transfers the native token to the contract
    assertEq(address(nativeToERC20Swapper).balance, 0);
    assertEq(_owner.balance, 1e18);

    // it sets the swapped flag to true
    assertEq(nativeToERC20Swapper.swapped(), true);
  }

  function test_SwapWhenSwappingToNativeTokenToTheContract() public {
    test_DepositWhenPassingValidErc20TokenAmount();

    vm.deal(_owner, 1 ether);

    vm.expectEmit(true, true, true, true);
    emit ISwapper.TokensSwapped(1e18, 1e18);

    vm.prank(_owner);
    erc20ToNativeSwapper.swap{value: 1 ether}();

    // it transfers the native token to the contract
    assertEq(_owner.balance, 0);
    assertEq(address(erc20ToNativeSwapper).balance, 1 ether);

    // it transfers the ERC20 tokens to the _owner
    assertEq(wunder.balanceOf(_owner), 1e18);
    assertEq(wunder.balanceOf(address(erc20ToNativeSwapper)), 0);

    // it sets the swapped flag to true
    assertEq(erc20ToNativeSwapper.swapped(), true);
  }

  function test_SwapWhenTransferringInsufficientTokensToTheContract() public {
    test_DepositWhenPassingValidNativeTokenAmount();
    vm.expectRevert('ERC20: subtraction underflow');
    vm.prank(_owner);
    // it reverts
    nativeToERC20Swapper.swap();
  }

  function test_SwapWhenPassingAmountOf0() public {
    test_DepositWhenPassingValidErc20TokenAmount();
    vm.expectRevert(ISwapper.Swapper_NotEnoughLiquidity.selector);
    vm.deal(_owner, 1 ether);
    vm.prank(_owner);
    // it reverts
    erc20ToNativeSwapper.swap();
  }

  function test_SwapWhenCalledAfterSwap() public {
    test_SwapWhenSwappingToERC20TokensToTheContract();
    vm.expectRevert(ISwapper.Swapper_SwapAlreadyExecuted.selector);
    vm.prank(_owner);
    // it reverts
    nativeToERC20Swapper.swap();
  }

  function test_SwapWhenCalledByANon_owner() public {
    // it reverts
    vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, _bob));
    vm.prank(_bob);
    nativeToERC20Swapper.swap();
  }

  function test_WithdrawWhenWithdrawingNativeToken() public {
    test_SwapWhenSwappingToNativeTokenToTheContract();

    // it emits SwappedTokensWithdrawn
    vm.expectEmit(true, true, true, true);
    emit ISwapper.SwappedTokensWithdrawn(address(_bob), 1e18);

    vm.startPrank(_bob);

    erc20ToNativeSwapper.withdraw();
    vm.stopPrank();

    // it transfers the tokens to the user
    assertEq(address(_bob).balance, 1e18);
    assertEq(address(erc20ToNativeSwapper).balance, 0);

    // it updates the hasWithdrawn flag
    ISwapper.SwapInfo memory swapInfo = erc20ToNativeSwapper.userToSwapInfo(_bob);
    assertEq(swapInfo.hasWithdrawn, true);
  }

  function test_WithdrawWhenWithdrawingERC20Token() public {
    test_SwapWhenSwappingToERC20TokensToTheContract();

    // it emits SwappedTokensWithdrawn
    vm.expectEmit(true, true, true, true);
    emit ISwapper.SwappedTokensWithdrawn(address(_bob), 1e18);

    vm.startPrank(_bob);
    nativeToERC20Swapper.withdraw();
    vm.stopPrank();

    // it transfers the tokens to the user
    assertEq(wunder.balanceOf(address(_bob)), 1e18);
    assertEq(wunder.balanceOf(address(nativeToERC20Swapper)), 0);

    // it updates the hasWithdrawn flag
    ISwapper.SwapInfo memory swapInfo = nativeToERC20Swapper.userToSwapInfo(_bob);
    assertEq(swapInfo.hasWithdrawn, true);
  }

  function test_WithdrawWhenNoTokensToWithdraw() public {
    test_SwapWhenSwappingToERC20TokensToTheContract();

    vm.expectRevert(ISwapper.Swapper_NoTokensToWithdraw.selector);
    vm.prank(makeAddr('user'));
    // it reverts
    nativeToERC20Swapper.withdraw();
  }

  function test_WithdrawWhenAlreadyWithdrawn() public {
    test_SwapWhenSwappingToNativeTokenToTheContract();
    vm.startPrank(_bob);
    erc20ToNativeSwapper.withdraw();

    vm.expectRevert(ISwapper.Swapper_AlreadyWithdrawn.selector);
    // it reverts
    erc20ToNativeSwapper.withdraw();

    vm.stopPrank();
  }

  function test_WithdrawWhenCalledBeforeSwap() public {
    test_DepositWhenPassingValidNativeTokenAmount();
    vm.expectRevert(ISwapper.Swapper_SwapNotExecuted.selector);
    vm.prank(_bob);
    // it reverts
    nativeToERC20Swapper.withdraw();
  }

  function test_WithdrawDepositWhenWithdrawing() public {
    test_DepositWhenPassingValidNativeTokenAmount();

    // it emits DepositWithdrawn
    vm.expectEmit(true, true, true, true);
    emit ISwapper.DepositWithdrawn(address(_bob), 1e18);

    vm.prank(_bob);
    nativeToERC20Swapper.withdrawDeposit();

    // it returns the deposit token amount to the user
    assertEq(address(nativeToERC20Swapper).balance, 0);
    assertEq(_bob.balance, 1e18);

    // it deletes the swap info
    ISwapper.SwapInfo memory swapInfo = nativeToERC20Swapper.userToSwapInfo(_bob);
    assertEq(swapInfo.depositTokenAmount, 0);
    assertEq(swapInfo.hasWithdrawn, false);
  }

  function test_WithdrawDepositWhenNoTokensToWithdraw() public {
    vm.expectRevert(ISwapper.Swapper_NoTokensToWithdraw.selector);
    vm.prank(_bob);
    // it reverts
    nativeToERC20Swapper.withdrawDeposit();
  }

  function test_WithdrawDepositWhenCalledAfterSwap() public {
    test_SwapWhenSwappingToERC20TokensToTheContract();
    vm.expectRevert(ISwapper.Swapper_SwapAlreadyExecuted.selector);
    vm.prank(_bob);
    // it reverts
    nativeToERC20Swapper.withdrawDeposit();
  }

  function test_EmergencyWithdrawWhenWithdrawing() public {
    // deal the contract with 1 ether
    vm.deal(address(nativeToERC20Swapper), 1 ether);

    vm.expectEmit(true, true, true, true);
    emit ISwapper.EmergencyWithdraw(_owner, address(0), 1 ether);

    vm.prank(_owner);
    // it emits EmergencyWithdraw
    nativeToERC20Swapper.emergencyWithdraw(address(0), 1 ether);

    // it transfers the tokens to the user
    assertEq(address(nativeToERC20Swapper).balance, 0);
    assertEq(_owner.balance, 1 ether);
  }

  function test_EmergencyWithdrawWhenPassingAmountOf0() public {
    vm.expectRevert(ISwapper.Swapper_NoTokensToWithdraw.selector);
    vm.prank(_owner);
    // it reverts
    nativeToERC20Swapper.emergencyWithdraw(address(0), 0);
  }

  function test_EmergencyWithdrawWhenCalledByANon_owner() public {
    // it reverts
    vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, _bob));
    vm.prank(_bob);
    nativeToERC20Swapper.emergencyWithdraw(address(0), 1e18);
  }

  function test_EmergencyWithdrawWhenPassingAmountGreaterThanTheBalance() public {
    vm.deal(address(nativeToERC20Swapper), 1 ether);
    vm.expectRevert(ISwapper.Swapper_NotEnoughLiquidity.selector);
    vm.prank(_owner);
    // it reverts
    nativeToERC20Swapper.emergencyWithdraw(address(0), 2 ether);
  }
}
