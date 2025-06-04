// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import {Ownable} from '@openzeppelin/access/Ownable.sol';
import {IUniswapV2Router02} from 'node_modules/@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol';

import {Test} from 'forge-std/Test.sol';
import {ISwapperV2, SwapperV2} from 'src/contracts/SwapperV2.sol';
import {MockERC20} from 'test/mocks/MockERC20.sol';

contract UnitSwapperV2 is Test {
  SwapperV2 public nativeToERC20Swapper;
  SwapperV2 public erc20ToNativeSwapper;
  SwapperV2 public erc20ToErc20Swapper;

  address internal _mockRouter = makeAddr('_router');

  MockERC20 public wunder;
  MockERC20 public kinder;

  address internal _owner = makeAddr('_owner');
  address internal _bob = makeAddr('_bob');
  address internal _alice = makeAddr('_alice');

  function setUp() public {
    vm.startPrank(_owner);

    // Setup ERC20 tokens
    wunder = new MockERC20();
    wunder.initialize('WUNDER', 'WUN', 8);
    kinder = new MockERC20();
    kinder.initialize('KINDER', 'KIN', 8);

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

  function test_DepositWhenPassingValidERC20TokenAmount() external {
    wunder.mint(_bob, 1e8);

    vm.startPrank(_bob);

    wunder.approve(address(erc20ToNativeSwapper), 1e8);

    vm.expectEmit(true, true, true, true);
    emit ISwapperV2.TokensDeposited(_bob, 1e8);

    erc20ToNativeSwapper.deposit(1e8);

    // it deposits the amount to the contract
    assertEq(wunder.balanceOf(address(erc20ToNativeSwapper)), 1e8);
    assertEq(wunder.balanceOf(address(_bob)), 0);

    // it appends a deposit entry for the user
    ISwapperV2.Deposits[] memory deposits = erc20ToNativeSwapper.getDeposits(_bob);
    assertEq(deposits.length, 1);
    assertEq(deposits[0].amount, 1e8);
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
    // it does not withdraw swapped deposits (only pre-swap deposits)
  }

  function test_WithdrawDepositWhenUserHasBothPre_swapAndPost_swapDeposits() external {
    // it only withdraws pre-swap deposits
    // it leaves post-swap deposits for future swaps
  }

  // function test_SwapWhenSwappingNativeToERC20TokensToTheContract() external {
  //   test_DepositWhenPassingValidNativeTokenAmount();
  //   assertEq(nativeToERC20Swapper.getSwapIndex(), 0);

  //   vm.mockCall{value: 1e18}(
  //     address(_mockRouter),
  //     abi.encodeWithSelector(
  //       IUniswapV2Router02.swapExactETHForTokens.selector,
  //       0,
  //       _constructTokenPath(address(0), address(wunder)),
  //       address(nativeToERC20Swapper),
  //       block.timestamp
  //     ),
  //     abi.encode([1 ether, 1e18])
  //   );

  //   vm.startPrank(_owner);

  //   // TODO: How do i transfer wunder to the contract ?

  //   // it emits TokensSwapped
  //   // vm.expectEmit(true, true, true, true);
  //   // emit ISwapper.TokensSwapped(1e18, 1e18);

  //   nativeToERC20Swapper.swap();
  //   vm.stopPrank();

  //   vm.expectCall(
  //     address(_mockRouter),
  //     abi.encodeWithSelector(
  //       IUniswapV2Router02.swapExactETHForTokens.selector,
  //       0,
  //       _constructTokenPath(address(0), address(wunder)),
  //       address(nativeToERC20Swapper),
  //       block.timestamp
  //     )
  //   );

  //   // it swaps via Uniswap V2 router
  //   // it records the swap rate for the round
  //   SwapperV2.SwapRateInfo memory _swapRateInfo = nativeToERC20Swapper.getSwapRateInfo(0);
  //   assertEq(_swapRateInfo.totalDeposited, 1e18);
  //   assertEq(_swapRateInfo.totalSwapped, 1e18);

  //   // it increments the swap index
  //   assertEq(nativeToERC20Swapper.getSwapIndex(), 1);
  // }

  function test_SwapWhenSwappingERC20ToNativeTokenToTheContract() external {
    // it swaps via Uniswap V2 router
    // it records the swap rate for the round
    // it increments the swap index
    // it emits TokensSwapped
  }

  function test_SwapWhenSwappingERC20ToERC20TokensToTheContract() external {
    // it swaps via Uniswap V2 router
    // it records the swap rate for the round
    // it increments the swap index
    // it emits TokensSwapped
  }

  function test_SwapWhenCalledByANon_owner() external {
    // it reverts
    vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, _bob));
    vm.prank(_bob);
    nativeToERC20Swapper.swap();
  }

  function test_WithdrawWhenWithdrawingAfterASwap() external {
    // it transfers the correct share of swapped tokens to the user
    // it deletes the user's deposit entries for swapped rounds
    // it emits SwappedTokensWithdrawn
  }

  function test_WithdrawWhenUserHasDepositsFromMultipleRounds() external {
    // it calculates and transfers the sum of all eligible swapped tokens
    // it deletes all user's deposit entries
  }

  function test_WithdrawWhenNoTokensToWithdraw() external {
    // it reverts
  }

  function test_WithdrawWhenCalledBeforeAnySwap() external {
    // it reverts or returns 0
  }

  function test_GetSwapTokenAmountWhenCalledAfterASwap() external {
    // it returns the correct withdrawable amount for the user
    // it returns 0 if user has no deposits
  }

  function test_GetSwapTokenAmountWhenCalledBeforeAnySwap() external {
    // it returns 0
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
    // it tracks deposits and swaps per round
    // it allows users to participate in multiple rounds
    // it calculates correct withdrawable amounts for each round
  }

  function test_SwapWhenSomeUsersWithdrawBeforeSwapAndOthersAfter() external {
    // it only includes active deposits in the swap
    // it does not double-count or lose user funds
  }

  function _constructTokenPath(
    address _depositedToken,
    address _swappedToken
  ) internal view returns (address[] memory path) {
    path = new address[](2);

    if (_depositedToken == address(0)) {
      path[0] = IUniswapV2Router02(_mockRouter).WETH();
    } else {
      path[0] = _depositedToken;
    }

    if (_swappedToken == address(0)) {
      path[1] = IUniswapV2Router02(_mockRouter).WETH();
    } else {
      path[1] = _swappedToken;
    }
  }
}
