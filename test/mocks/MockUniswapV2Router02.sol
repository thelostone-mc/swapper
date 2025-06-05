// solhint-disable
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import {IUniswapV2Router02} from '@uniswap/v2-periphery/interfaces/IUniswapV2Router02.sol';
import {MockERC20} from 'test/mocks/MockERC20.sol';

contract MockUniswapV2Router02 is IUniswapV2Router02 {
  function WETH() external pure override returns (address) {
    return 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
  }

  function swapExactETHForTokens(
    uint256, /*amountOutMin*/
    address[] calldata path,
    address to,
    uint256 /*deadline*/
  ) external payable override returns (uint256[] memory amounts) {
    amounts = new uint256[](2);
    amounts[0] = msg.value;
    amounts[1] = msg.value * 2; // 1:2 ratio
    // Mint output tokens to recipient
    MockERC20 outputToken = MockERC20(path[path.length - 1]);
    outputToken.mint(to, amounts[1]);
  }

  function swapTokensForExactETH(
    uint /*amountOut*/,
    uint amountInMax,
    address[] calldata /*path*/,
    address /*to*/,
    uint /*deadline*/
  ) external pure override returns (uint[] memory amounts) {
    amounts = new uint[](2);
    amounts[0] = amountInMax;
    amounts[1] = amountInMax / 2; // 2:1 ratio (output is half the input)
  }

  function swapTokensForExactTokens(
    uint256, /*amountOut*/
    uint256, /*amountInMax*/
    address[] calldata, /*path*/
    address, /*to*/
    uint256 /*deadline*/
  ) external pure override returns (uint256[] memory) {
    revert();
  }

  function swapETHForExactTokens(
    uint256, /*amountOut*/
    address[] calldata, /*path*/
    address, /*to*/
    uint256 /*deadline*/
  ) external payable override returns (uint256[] memory) {
    revert();
  }

  function swapExactTokensForETH(
    uint amountIn,
    uint /*amountOutMin*/,
    address[] calldata path,
    address /*to*/,
    uint /*deadline*/
  ) external override returns (uint[] memory amounts) {
    amounts = new uint[](2);
    amounts[0] = amountIn;
    amounts[1] = amountIn / 2; // 2:1 ratio (output is half the input)
    // Burn input tokens from the Swapper contract
    MockERC20 inputToken = MockERC20(path[0]);
    inputToken.burnFrom(msg.sender, amountIn);
  }

  function swapExactTokensForTokens(
    uint256 amountIn,
    uint256, /*amountOutMin*/
    address[] calldata path,
    address to,
    uint256 /*deadline*/
  ) external override returns (uint256[] memory amounts) {
    amounts = new uint256[](2);
    amounts[0] = amountIn;
    amounts[1] = amountIn * 4; // 1:4 ratio
    // Mint output tokens to recipient
    MockERC20 outputToken = MockERC20(path[path.length - 1]);
    outputToken.mint(to, amounts[1]);

    // Burn input tokens from the Swapper contract
    MockERC20 inputToken = MockERC20(path[0]);
    inputToken.burnFrom(msg.sender, amountIn);
  }

  // The following are required by the interface but not used in your tests. They can revert or return dummy values.
  function factory() external pure override returns (address) {
    revert();
  }

  function addLiquidity(
    address,
    address,
    uint256,
    uint256,
    uint256,
    uint256,
    address,
    uint256
  ) external pure override returns (uint256, uint256, uint256) {
    revert();
  }

  function addLiquidityETH(
    address,
    uint256,
    uint256,
    uint256,
    address,
    uint256
  ) external payable override returns (uint256, uint256, uint256) {
    revert();
  }

  function removeLiquidity(
    address,
    address,
    uint256,
    uint256,
    uint256,
    address,
    uint256
  ) external pure override returns (uint256, uint256) {
    revert();
  }

  function removeLiquidityETH(
    address,
    uint256,
    uint256,
    uint256,
    address,
    uint256
  ) external pure override returns (uint256, uint256) {
    revert();
  }

  function removeLiquidityWithPermit(
    address,
    address,
    uint256,
    uint256,
    uint256,
    address,
    uint256,
    bool,
    uint8,
    bytes32,
    bytes32
  ) external pure override returns (uint256, uint256) {
    revert();
  }

  function removeLiquidityETHWithPermit(
    address,
    uint256,
    uint256,
    uint256,
    address,
    uint256,
    bool,
    uint8,
    bytes32,
    bytes32
  ) external pure override returns (uint256, uint256) {
    revert();
  }

  function quote(uint256, uint256, uint256) external pure override returns (uint256) {
    revert();
  }

  function getAmountOut(uint256, uint256, uint256) external pure override returns (uint256) {
    revert();
  }

  function getAmountIn(uint256, uint256, uint256) external pure override returns (uint256) {
    revert();
  }

  function getAmountsOut(uint256, address[] calldata) external pure override returns (uint256[] memory) {
    revert();
  }

  function getAmountsIn(uint256, address[] calldata) external pure override returns (uint256[] memory) {
    revert();
  }

  function removeLiquidityETHSupportingFeeOnTransferTokens(
    address,
    uint256,
    uint256,
    uint256,
    address,
    uint256
  ) external pure override returns (uint256) {
    revert();
  }

  function removeLiquidityETHWithPermitSupportingFeeOnTransferTokens(
    address,
    uint256,
    uint256,
    uint256,
    address,
    uint256,
    bool,
    uint8,
    bytes32,
    bytes32
  ) external pure override returns (uint256) {
    revert();
  }

  function swapExactTokensForTokensSupportingFeeOnTransferTokens(
    uint256,
    uint256,
    address[] calldata,
    address,
    uint256
  ) external pure override {
    revert();
  }

  function swapExactETHForTokensSupportingFeeOnTransferTokens(
    uint256,
    address[] calldata,
    address,
    uint256
  ) external payable override {
    revert();
  }

  function swapExactTokensForETHSupportingFeeOnTransferTokens(
    uint256,
    uint256,
    address[] calldata,
    address,
    uint256
  ) external pure override {
    revert();
  }
}
