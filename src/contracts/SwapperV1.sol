// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

// External Imports
import {Ownable} from '@openzeppelin/access/Ownable.sol';
import {IERC20} from '@openzeppelin/token/ERC20/IERC20.sol';
import {SafeERC20} from '@openzeppelin/token/ERC20/utils/SafeERC20.sol';
import {ReentrancyGuard} from '@openzeppelin/utils/ReentrancyGuard.sol';

// Internal Imports
import {ISwapperV1} from 'interfaces/ISwapperV1.sol';

contract SwapperV1 is ISwapperV1, Ownable, ReentrancyGuard {
  using SafeERC20 for IERC20;

  /*///////////////////////////////////////////////////////////////
                            Storage
    //////////////////////////////////////////////////////////////*/

  /// @inheritdoc ISwapperV1
  address public immutable DEPOSITED_TOKEN;

  /// @inheritdoc ISwapperV1
  address public immutable SWAPPED_TOKEN;

  /// @inheritdoc ISwapperV1
  bool public swapped;

  /// @notice Mapping of user to swap info
  mapping(address user => SwapInfo swapInfo) private _userToSwapInfo;

  modifier onlyBeforeSwap() {
    if (swapped) revert SwapperV1_SwapAlreadyExecuted();
    _;
  }

  modifier onlyAfterSwap() {
    if (!swapped) revert SwapperV1_SwapNotExecuted();
    _;
  }

  /*///////////////////////////////////////////////////////////////
                            Constructor
    //////////////////////////////////////////////////////////////*/

  constructor(address _depositedToken, address _swappedToken) Ownable(msg.sender) {
    if (_depositedToken == _swappedToken) revert SwapperV1_InvalidTokens();

    DEPOSITED_TOKEN = _depositedToken;
    SWAPPED_TOKEN = _swappedToken;
  }

  /*///////////////////////////////////////////////////////////////
                            External Functions
    //////////////////////////////////////////////////////////////*/

  /// @inheritdoc ISwapperV1
  function deposit(uint256 _amount) external payable onlyBeforeSwap {
    if (_amount == 0) revert SwapperV1_InvalidAmount();

    SwapInfo storage _swapInfo = _userToSwapInfo[msg.sender];

    // Ensure funds are deposited to the swapper contract
    if (DEPOSITED_TOKEN == address(0)) {
      if (msg.value != _amount) revert SwapperV1_AmountMismatch();
    } else {
      if (msg.value != 0) revert SwapperV1_AmountMismatch();
      // TODO: Can add IERC20Permit but not needed for now
      IERC20(DEPOSITED_TOKEN).safeTransferFrom(msg.sender, address(this), _amount);
    }

    // Update the swap info
    _swapInfo.depositTokenAmount += _amount;

    emit TokensDeposited(msg.sender, _amount);
  }

  /// @inheritdoc ISwapperV1
  function swap() external payable onlyOwner onlyBeforeSwap nonReentrant {
    uint256 _tokenBalance = _getTokenBalance(DEPOSITED_TOKEN);

    // Deposit tokens into contract
    if (SWAPPED_TOKEN != address(0)) {
      IERC20(SWAPPED_TOKEN).safeTransferFrom(msg.sender, address(this), _tokenBalance);
    }

    // Expect liquidity to be equal to the deposited token balance (1:1 swap)
    if (_tokenBalance != _getTokenBalance(SWAPPED_TOKEN)) {
      revert SwapperV1_NotEnoughLiquidity();
    }

    // Set the swapped flag to true
    swapped = true;

    // Transfer the tokens to the owner
    if (DEPOSITED_TOKEN == address(0)) {
      payable(msg.sender).transfer(_tokenBalance);
    } else {
      IERC20(DEPOSITED_TOKEN).safeTransfer(msg.sender, _tokenBalance);
    }

    /// @dev swap is 1:1 so we can use the same amount for both
    emit TokensSwapped(_tokenBalance, _tokenBalance);
  }

  /// @inheritdoc ISwapperV1
  function withdrawDeposit() external onlyBeforeSwap nonReentrant {
    SwapInfo memory _swapInfo = _userToSwapInfo[msg.sender];

    uint256 _withdrawAmount = _swapInfo.depositTokenAmount;

    if (_withdrawAmount == 0) revert SwapperV1_NoTokensToWithdraw();

    // Delete the swap
    delete _userToSwapInfo[msg.sender];

    // Withdraw the tokens
    if (DEPOSITED_TOKEN == address(0)) {
      payable(msg.sender).transfer(_withdrawAmount);
    } else {
      IERC20(DEPOSITED_TOKEN).safeTransfer(msg.sender, _withdrawAmount);
    }

    // Emit the event
    emit DepositWithdrawn(msg.sender, _withdrawAmount);
  }

  /// @inheritdoc ISwapperV1
  function withdraw() external onlyAfterSwap nonReentrant {
    SwapInfo storage _swapInfo = _userToSwapInfo[msg.sender];

    if (_swapInfo.hasWithdrawn) revert SwapperV1_AlreadyWithdrawn();

    if (_swapInfo.depositTokenAmount == 0) revert SwapperV1_NoTokensToWithdraw();

    uint256 _swapTokenAmount = _getSwapTokenAmount(msg.sender);

    // Update the swap info
    _swapInfo.hasWithdrawn = true;

    // Withdraw the tokens
    if (SWAPPED_TOKEN == address(0)) {
      payable(msg.sender).transfer(_swapTokenAmount);
    } else {
      IERC20(SWAPPED_TOKEN).safeTransfer(msg.sender, _swapTokenAmount);
    }

    // Emit the event
    emit SwappedTokensWithdrawn(msg.sender, _swapTokenAmount);
  }

  /// @inheritdoc ISwapperV1
  function emergencyWithdraw(address token, uint256 amount) external onlyOwner {
    if (amount == 0) revert SwapperV1_NoTokensToWithdraw();

    if (_getTokenBalance(token) < amount) revert SwapperV1_NotEnoughLiquidity();

    if (token == address(0)) {
      payable(msg.sender).transfer(amount);
    } else {
      IERC20(token).safeTransfer(msg.sender, amount);
    }
    emit EmergencyWithdraw(msg.sender, token, amount);
  }

  /// @inheritdoc ISwapperV1
  function userToSwapInfo(address _user) external view returns (SwapInfo memory) {
    return _userToSwapInfo[_user];
  }

  /*///////////////////////////////////////////////////////////////
                            Public Functions
    //////////////////////////////////////////////////////////////*/

  /// @inheritdoc ISwapperV1
  function getSwapTokenAmount(address _user) public view onlyAfterSwap returns (uint256) {
    return _getSwapTokenAmount(_user);
  }

  /*///////////////////////////////////////////////////////////////
                            Internal Functions
    //////////////////////////////////////////////////////////////*/

  function _getSwapTokenAmount(address _user) internal view returns (uint256) {
    SwapInfo memory _swapInfo = _userToSwapInfo[_user];
    if (_swapInfo.hasWithdrawn) return 0;
    /// @dev We can return deposit token amount (as this is a 1:1 swap)
    return _swapInfo.depositTokenAmount;
  }

  function _getTokenBalance(address _token) internal view returns (uint256) {
    if (_token == address(0)) {
      return address(this).balance;
    } else {
      return IERC20(_token).balanceOf(address(this));
    }
  }
}
