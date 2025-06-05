// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import {Ownable} from '@openzeppelin/access/Ownable.sol';
import {IUniswapV2Router02} from 'node_modules/@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol';

import {Test} from 'forge-std/Test.sol';
import {ISwapperV2, SwapperV2} from 'src/contracts/SwapperV2.sol';
import {MockERC20} from 'test/mocks/MockERC20.sol';
import {MockUniswapV2Router02} from 'test/mocks/MockUniswapV2Router02.sol';

contract UnitSwapperV2 is Test {
  SwapperV2 public nativeToERC20Swapper;
  SwapperV2 public erc20ToNativeSwapper;
  SwapperV2 public erc20ToErc20Swapper;

  MockUniswapV2Router02 internal _mockRouter;

  MockERC20 public wunder;
  MockERC20 public kinder;

  address internal _owner = makeAddr('_owner');
  address internal _bob = makeAddr('_bob');
  address internal _alice = makeAddr('_alice');
  address internal _weth = makeAddr('weth');

  function setUp() public {
    vm.startPrank(_owner);

    // Setup ERC20 tokens
    wunder = new MockERC20();
    wunder.initialize('WUNDER', 'WUN', 18);
    kinder = new MockERC20();
    kinder.initialize('KINDER', 'KIN', 18);

    _mockRouter = new MockUniswapV2Router02();

    // Setup Swapper Contracts
    nativeToERC20Swapper = new SwapperV2(address(0), address(wunder), address(_mockRouter));
    erc20ToNativeSwapper = new SwapperV2(address(wunder), address(0), address(_mockRouter));
    erc20ToErc20Swapper = new SwapperV2(address(wunder), address(kinder), address(_mockRouter));

    vm.stopPrank();
  }

  function test_ConstructorWhenPassingValidTokens() external view {
    // it deploys
    assertEq(nativeToERC20Swapper.owner(), _owner);
    // it sets the deposited token
    assertEq(nativeToERC20Swapper.DEPOSITED_TOKEN(), address(0));
    // it sets the swapped token
    assertEq(nativeToERC20Swapper.SWAPPED_TOKEN(), address(wunder));
    // it sets the router
    assertEq(address(nativeToERC20Swapper.ROUTER()), address(_mockRouter));
  }

  function test_ConstructorWhenPassingSameTokenForDepositedAndSwapped() external {
    vm.expectRevert(ISwapperV2.Swapper_InvalidTokens.selector);
    new SwapperV2(address(wunder), address(wunder), address(_mockRouter));
  }

  function test_DepositWhenPassingValidNativeTokenAmount() public {
    vm.deal(_bob, 1 ether);
    // it emits TokensDeposited
    vm.expectEmit(true, true, true, true);
    emit ISwapperV2.TokensDeposited(_bob, 1 ether);

    vm.prank(_bob);
    nativeToERC20Swapper.deposit{value: 1 ether}(1e18);

    // it deposits the amount to the contract
    assertEq(address(_bob).balance, 0);
    assertEq(address(nativeToERC20Swapper).balance, 1 ether);

    // it appends a deposit entry for the user
    ISwapperV2.Deposits[] memory deposits = nativeToERC20Swapper.getDeposits(_bob);
    assertEq(deposits.length, 1);
    assertEq(deposits[0].amount, 1 ether);
    assertEq(deposits[0].swapIndex, 0);
  }

  function test_DepositWhenPassingValidERC20TokenAmount() public {
    wunder.mint(_bob, 1e18);

    vm.startPrank(_bob);

    wunder.approve(address(erc20ToNativeSwapper), 1e18);

    vm.expectEmit(true, true, true, true);
    emit ISwapperV2.TokensDeposited(_bob, 1e18);

    erc20ToNativeSwapper.deposit(1e18);

    // it deposits the amount to the contract
    assertEq(wunder.balanceOf(address(erc20ToNativeSwapper)), 1e18);
    assertEq(wunder.balanceOf(address(_bob)), 0);

    // it appends a deposit entry for the user
    ISwapperV2.Deposits[] memory deposits = erc20ToNativeSwapper.getDeposits(_bob);
    assertEq(deposits.length, 1);
    assertEq(deposits[0].amount, 1e18);
    assertEq(deposits[0].swapIndex, 0);
  }

  function test_DepositWhenDepositingMoreThanOnce() external {
    test_DepositWhenPassingValidNativeTokenAmount();

    vm.deal(_bob, 1 ether);
    vm.prank(_bob);
    nativeToERC20Swapper.deposit{value: 1 ether}(1e18);

    // it appends multiple deposit entries for the user
    // it updates the balance of the contract
    assertEq(address(nativeToERC20Swapper).balance, 2 ether);

    // it appends multiple deposit entries for the user
    ISwapperV2.Deposits[] memory deposits = nativeToERC20Swapper.getDeposits(_bob);
    assertEq(deposits.length, 2);
    assertEq(deposits[0].amount, 1 ether);
    assertEq(deposits[0].swapIndex, 0);
    assertEq(deposits[1].amount, 1 ether);
    assertEq(deposits[1].swapIndex, 0);
  }

  function test_DepositWhenPassingAmountOf0() external {
    vm.expectRevert(ISwapperV2.Swapper_InvalidAmount.selector);
    vm.prank(_bob);
    // it reverts
    nativeToERC20Swapper.deposit{value: 0}(0);
  }

  function test_DepositWhenBalanceOfTheContractIsLessThanTheAmountSent() external {
    vm.deal(_bob, 1 ether);

    vm.expectRevert(ISwapperV2.Swapper_AmountMismatch.selector);
    vm.prank(_bob);
    // it reverts
    nativeToERC20Swapper.deposit{value: 0.5 ether}(1e18);
  }

  function test_DepositWhenBalanceOfTheContractIsGreaterThanTheAmountSent() external {
    vm.deal(_bob, 1 ether);
    vm.expectRevert(ISwapperV2.Swapper_AmountMismatch.selector);

    vm.prank(_bob);
    // it reverts
    nativeToERC20Swapper.deposit{value: 1 ether}(0.5 ether);
  }

  function test_WithdrawDepositWhenWithdrawingBeforeAnySwap() external {
    test_DepositWhenPassingValidNativeTokenAmount();

    vm.startPrank(_bob);

    // it emits DepositWithdrawn
    vm.expectEmit(true, true, true, true);
    emit ISwapperV2.DepositWithdrawn(address(_bob), 1 ether);
    nativeToERC20Swapper.withdrawDeposit();

    vm.stopPrank();

    // it returns the deposit token amount to the user
    assertEq(address(_bob).balance, 1 ether);
    assertEq(address(nativeToERC20Swapper).balance, 0);
    // it deletes the user's deposit entries
    ISwapperV2.Deposits[] memory deposits = nativeToERC20Swapper.getDeposits(_bob);
    assertEq(deposits.length, 0);
  }

  function test_WithdrawDepositWhenNoTokensToWithdraw() external {
    vm.expectRevert(ISwapperV2.Swapper_NoTokensToWithdraw.selector);
    vm.prank(_bob);
    // it reverts
    nativeToERC20Swapper.withdrawDeposit();
  }

  function test_WithdrawDepositWhenCalledAfterSwapForDepositsAlreadySwapped() external {
    // deposit 1 eth and swap it to 2 wunder
    test_SwapWhenSwappingNativeToERC20TokensToTheContract();

    // withdraw deposit
    vm.expectRevert(ISwapperV2.Swapper_NoTokensToWithdraw.selector);
    vm.prank(_bob);
    nativeToERC20Swapper.withdrawDeposit();

  }

  function test_WithdrawDepositWhenUserHasBothPre_swapAndPost_swapDeposits() external {
    // deposit 1 eth and swap it to 2 wunder
    test_SwapWhenSwappingNativeToERC20TokensToTheContract();

    // deposit 1 eth again
    vm.deal(_bob, 1 ether);
    vm.prank(_bob);
    nativeToERC20Swapper.deposit{value: 1 ether}(1e18);

    ISwapperV2.Deposits[] memory deposits_before_withdraw = nativeToERC20Swapper.getDeposits(_bob);
    assertEq(deposits_before_withdraw.length, 2);

    assertEq(address(nativeToERC20Swapper).balance, 1 ether);
    assertEq(wunder.balanceOf(address(nativeToERC20Swapper)), 2 ether);

    // withdraw deposit
    vm.startPrank(_bob);

    vm.expectEmit(true, true, true, true);
    emit ISwapperV2.DepositWithdrawn(address(_bob), 1 ether);
  
    nativeToERC20Swapper.withdrawDeposit();
    vm.stopPrank();

    assertEq(address(nativeToERC20Swapper).balance, 0);
    assertEq(wunder.balanceOf(address(nativeToERC20Swapper)), 2 ether);

    ISwapperV2.Deposits[] memory deposits = nativeToERC20Swapper.getDeposits(_bob);
    assertEq(deposits.length, 1);

    assertEq(deposits[0].amount, 1 ether);
    assertEq(deposits[0].swapIndex, 0);
  }

  function test_SwapWhenSwappingNativeToERC20TokensToTheContract() public {
    test_DepositWhenPassingValidNativeTokenAmount();
    assertEq(nativeToERC20Swapper.getSwapIndex(), 0);

    vm.startPrank(_owner);

    // it emits TokensSwapped
    vm.expectEmit(true, true, true, true);
    emit ISwapperV2.TokensSwapped(1e18, 2e18);

    nativeToERC20Swapper.swap();
    vm.stopPrank();

    // it swaps via Uniswap V2 router
    // it records the swap rate for the round
    SwapperV2.SwapRateInfo memory _swapRateInfo = nativeToERC20Swapper.getSwapRateInfo(0);
    assertEq(_swapRateInfo.totalDeposited, 1e18);
    assertEq(_swapRateInfo.totalSwapped, 2e18);

    // it increments the swap index
    assertEq(nativeToERC20Swapper.getSwapIndex(), 1);

    assertEq(address(nativeToERC20Swapper).balance, 0);

    // The Swapper contract should now hold 2 ether worth of wunder tokens (1:2 ratio)
    assertEq(wunder.balanceOf(address(nativeToERC20Swapper)), 2 ether);
  }

  function test_SwapWhenSwappingERC20ToNativeTokenToTheContract() public {
    test_DepositWhenPassingValidERC20TokenAmount();
    assertEq(erc20ToNativeSwapper.getSwapIndex(), 0);

    vm.startPrank(_owner);

    // it emits TokensSwapped
    vm.expectEmit(true, true, true, true);
    emit ISwapperV2.TokensSwapped(1e18, 0.5 ether);

    erc20ToNativeSwapper.swap();
    vm.deal(address(erc20ToNativeSwapper), 0.5 ether);
    
    vm.stopPrank();

    // it swaps via Uniswap V2 router
    // it records the swap rate for the round
    SwapperV2.SwapRateInfo memory _swapRateInfo = erc20ToNativeSwapper.getSwapRateInfo(0);
    assertEq(_swapRateInfo.totalDeposited, 1e18);
    assertEq(_swapRateInfo.totalSwapped, 0.5 ether);

    // it increments the swap index
    assertEq(erc20ToNativeSwapper.getSwapIndex(), 1);

    assertEq(address(erc20ToNativeSwapper).balance, 0.5 ether);
    assertEq(wunder.balanceOf(address(erc20ToNativeSwapper)), 0);
  }

  function test_SwapWhenSwappingERC20ToERC20TokensToTheContract() external {

    // Deposit
    wunder.mint(_bob, 1e18);
    vm.startPrank(_bob);
    wunder.approve(address(erc20ToErc20Swapper), 1e18);
    erc20ToErc20Swapper.deposit(1e18);
    vm.stopPrank();

    assertEq(erc20ToErc20Swapper.getSwapIndex(), 0);

    vm.startPrank(_owner);

    // Swap
    vm.expectEmit(true, true, true, true);
    emit ISwapperV2.TokensSwapped(1e18, 4e18);

    erc20ToErc20Swapper.swap();

    vm.stopPrank();

    // it swaps via Uniswap V2 router
    // it records the swap rate for the round
    SwapperV2.SwapRateInfo memory _swapRateInfo = erc20ToErc20Swapper.getSwapRateInfo(0);
    assertEq(_swapRateInfo.totalDeposited, 1e18);
    assertEq(_swapRateInfo.totalSwapped, 4e18);

    // it increments the swap index
    assertEq(erc20ToErc20Swapper.getSwapIndex(), 1);

    // Verify the swap was successful
    assertEq(wunder.balanceOf(address(erc20ToErc20Swapper)), 0);
    assertEq(kinder.balanceOf(address(erc20ToErc20Swapper)), 4 ether);
  }

  function test_SwapWhenCalledByANon_owner() external {
    // it reverts
    vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, _bob));
    vm.prank(_bob);
    nativeToERC20Swapper.swap();
  }

  function test_WithdrawWhenWithdrawingAfterASwap() public {

    test_SwapWhenSwappingNativeToERC20TokensToTheContract();

    assertEq(wunder.balanceOf(address(_bob)), 0);

    vm.startPrank(_bob);

    // it emits SwappedTokensWithdrawn
    vm.expectEmit(true, true, true, true);
    emit ISwapperV2.SwappedTokensWithdrawn(address(_bob), 2 ether);

    nativeToERC20Swapper.withdraw();

    vm.stopPrank();

    // it transfers the correct share of swapped tokens to the user
    assertEq(wunder.balanceOf(address(_bob)), 2 ether);
    assertEq(nativeToERC20Swapper.getSwapIndex(), 1);

    // it deletes the user's deposit entries for swapped rounds
    ISwapperV2.Deposits[] memory deposits = nativeToERC20Swapper.getDeposits(_bob);
    assertEq(deposits.length, 0);
  }

  function test_WithdrawWhenUserHasDepositsFromMultipleRounds() external {

    test_SwapWhenSwappingNativeToERC20TokensToTheContract();
    
    // deposit and swap 1 ether again
    vm.deal(_bob, 1 ether);
    vm.prank(_bob);
    nativeToERC20Swapper.deposit{value: 1 ether}(1e18);
    vm.prank(_owner);
    nativeToERC20Swapper.swap();

    assertEq(wunder.balanceOf(address(_bob)), 0);

    vm.startPrank(_bob);

    // it emits SwappedTokensWithdrawn
    vm.expectEmit(true, true, true, true);
    emit ISwapperV2.SwappedTokensWithdrawn(address(_bob), 4 ether);

    nativeToERC20Swapper.withdraw();

    vm.stopPrank();

    // it transfers the correct share of swapped tokens to the user
    assertEq(wunder.balanceOf(address(_bob)), 4 ether);
    assertEq(nativeToERC20Swapper.getSwapIndex(), 2);

    // it deletes the user's deposit entries for swapped rounds
    ISwapperV2.Deposits[] memory deposits = nativeToERC20Swapper.getDeposits(_bob);
    assertEq(deposits.length, 0);
  }

  function test_WithdrawWhenNoTokensToWithdraw() external {
    test_WithdrawWhenWithdrawingAfterASwap();
    vm.expectRevert(ISwapperV2.Swapper_NoTokensToWithdraw.selector);
    vm.prank(_bob);
    // it reverts
    nativeToERC20Swapper.withdraw();
  }

  function test_WithdrawWhenCalledBeforeAnySwap() external {
    // it reverts or returns 0
    vm.expectRevert(ISwapperV2.Swapper_NoTokensToWithdraw.selector);
    vm.prank(_bob);
    // it reverts
    nativeToERC20Swapper.withdraw();
  }

  function test_GetSwapTokenAmountWhenCalledAfterASwap() external {
    test_SwapWhenSwappingNativeToERC20TokensToTheContract();
    // it returns the correct withdrawable amount for the user
    assertEq(nativeToERC20Swapper.getSwapTokenAmount(_bob), 2 ether);
  }

  function test_GetSwapTokenAmountWhenCalledBeforeAnySwap() external view {
    // it returns 0
    assertEq(nativeToERC20Swapper.getSwapTokenAmount(_bob), 0);
  }

  function test_EmergencyWithdrawWhenWithdrawing() external {
    // deal the contract with 1 ether
    vm.deal(address(nativeToERC20Swapper), 1 ether);

    vm.expectEmit(true, true, true, true);
    emit ISwapperV2.EmergencyWithdraw(_owner, address(0), 1 ether);

    vm.prank(_owner);
    // it emits EmergencyWithdraw
    nativeToERC20Swapper.emergencyWithdraw(address(0), 1 ether);

    // it transfers the tokens to the user
    assertEq(address(nativeToERC20Swapper).balance, 0);
    assertEq(_owner.balance, 1 ether);
  }

  function test_EmergencyWithdrawWhenPassingAmountOf0() external {
    vm.expectRevert(ISwapperV2.Swapper_NoTokensToWithdraw.selector);
    vm.prank(_owner);
    // it reverts
    nativeToERC20Swapper.emergencyWithdraw(address(0), 0);
  }

  function test_EmergencyWithdrawWhenCalledByANon_owner() external {
    vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, _bob));
    vm.prank(_bob);
    // it reverts
    nativeToERC20Swapper.emergencyWithdraw(address(0), 1 ether);
  }

  function test_EmergencyWithdrawWhenPassingAmountGreaterThanTheBalance() external {
    vm.deal(address(nativeToERC20Swapper), 1 ether);
    vm.expectRevert(ISwapperV2.Swapper_NotEnoughLiquidity.selector);
    vm.prank(_owner);
    // it reverts
    nativeToERC20Swapper.emergencyWithdraw(address(0), 2 ether);
  }

  function test_SwapWhenUsersDepositsAndSwapsAndWithdrawsAndDepositsAgain() external {

    test_WithdrawWhenWithdrawingAfterASwap();

    vm.deal(_bob, 2 ether);
    vm.prank(_bob);
    nativeToERC20Swapper.deposit{value: 2 ether}(2 ether);

    // it tracks deposits and swaps per round
    ISwapperV2.Deposits[] memory deposits = nativeToERC20Swapper.getDeposits(_bob);
    assertEq(deposits.length, 1);

    assertEq(nativeToERC20Swapper.getSwapIndex(), 1);

    vm.prank(_owner);
    nativeToERC20Swapper.swap();

    ISwapperV2.SwapRateInfo memory swapRateInfo_x = nativeToERC20Swapper.getSwapRateInfo(0);
    assertEq(swapRateInfo_x.totalDeposited, 1 ether);
    assertEq(swapRateInfo_x.totalSwapped, 2 ether);

    ISwapperV2.SwapRateInfo memory swapRateInfo_y = nativeToERC20Swapper.getSwapRateInfo(1);
    assertEq(swapRateInfo_y.totalDeposited, 2 ether);
    assertEq(swapRateInfo_y.totalSwapped, 4 ether);

    assertEq(nativeToERC20Swapper.getSwapIndex(), 2);
    assertEq(nativeToERC20Swapper.getSwapTokenAmount(_bob), 4 ether);

    // it allows users to participate in multiple rounds
    // it calculates correct withdrawable amounts for each round
  }

  function test_SwapWhenSomeUsersWithdrawBeforeSwapAndOthersAfter() external {
    // it only includes active deposits in the swap
    // it does not double-count or lose user funds
    vm.deal(_bob, 1 ether);
    vm.deal(_alice, 1 ether);

    vm.prank(_bob);
    nativeToERC20Swapper.deposit{value: 1 ether}(1e18);

    vm.startPrank(_alice);
    nativeToERC20Swapper.deposit{value: 1 ether}(1e18);

    // alice withdraws deposit 
    nativeToERC20Swapper.withdrawDeposit();
    vm.stopPrank();

    vm.prank(_owner);
    nativeToERC20Swapper.swap();

    assertEq(nativeToERC20Swapper.getSwapIndex(), 1);
    ISwapperV2.SwapRateInfo memory swapRateInfo = nativeToERC20Swapper.getSwapRateInfo(0);
    assertEq(swapRateInfo.totalDeposited, 1 ether);
    assertEq(swapRateInfo.totalSwapped, 2 ether);
    
    assertEq(nativeToERC20Swapper.getSwapTokenAmount(_bob), 2 ether);
    assertEq(nativeToERC20Swapper.getSwapTokenAmount(_alice), 0);

    // Alice attempt to withdraw
    vm.expectRevert(ISwapperV2.Swapper_NoTokensToWithdraw.selector);
    vm.prank(_alice);
    nativeToERC20Swapper.withdraw();

    vm.startPrank(_bob);

    // it emits SwappedTokensWithdrawn
    vm.expectEmit(true, true, true, true);
    emit ISwapperV2.SwappedTokensWithdrawn(address(_bob), 2 ether);
    nativeToERC20Swapper.withdraw();
    
  }
}
