// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

// External Imports
import {Ownable} from '@openzeppelin/access/Ownable.sol';
import {IERC20} from '@openzeppelin/token/ERC20/IERC20.sol';
import {SafeERC20} from '@openzeppelin/token/ERC20/utils/SafeERC20.sol';
import {ReentrancyGuard} from '@openzeppelin/utils/ReentrancyGuard.sol';
import {IUniswapV2Router02} from '@uniswap/v2-periphery/interfaces/IUniswapV2Router02.sol';

// Internal Imports
import {ISwapperV2} from 'interfaces/ISwapperV2.sol';

contract SwapperV2 is ISwapperV2, Ownable, ReentrancyGuard {
  using SafeERC20 for IERC20;

  /*///////////////////////////////////////////////////////////////
                            Storage
  //////////////////////////////////////////////////////////////*/

  /// @notice The router to be used for swapping
  IUniswapV2Router02 public immutable ROUTER;

  /// @notice Index of the current swap
  uint256 internal _swapIndex;

  /// @inheritdoc ISwapperV2
  address public immutable DEPOSITED_TOKEN;

  /// @inheritdoc ISwapperV2
  address public immutable SWAPPED_TOKEN;

  /// @notice Mapping of user to thier deposited by swap index
  mapping(address user => Deposits[] deposits) private _userDeposits;

  /// @notice Mapping of swap index to the swap rate
  mapping(uint256 swapIndex => SwapRateInfo swapRateInfo) private _swaps;

  /*///////////////////////////////////////////////////////////////
                            Constructor
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Constructor
   * @param _depositedToken The address of the token to be deposited
   * @param _swappedToken The address of the token to be swapped
   * @param _router The address of the router to be used for swapping
   */
  constructor(address _depositedToken, address _swappedToken, address _router) Ownable(msg.sender) {
    if (_depositedToken == _swappedToken) revert Swapper_InvalidTokens();

    DEPOSITED_TOKEN = _depositedToken;
    SWAPPED_TOKEN = _swappedToken;
    ROUTER = IUniswapV2Router02(_router);
  }

  /*///////////////////////////////////////////////////////////////
                            External Functions
  //////////////////////////////////////////////////////////////*/

  /// @inheritdoc ISwapperV2
  function deposit(uint256 _amount) external payable {
    if (_amount == 0) revert Swapper_InvalidAmount();

    // Ensure funds are deposited to the swapper contract
    if (DEPOSITED_TOKEN == address(0)) {
      if (msg.value != _amount) revert Swapper_AmountMismatch();
    } else {
      if (msg.value != 0) revert Swapper_AmountMismatch();
      IERC20(DEPOSITED_TOKEN).safeTransferFrom(msg.sender, address(this), _amount);
    }

    // Add the deposit to the user's deposits by swap index
    _userDeposits[msg.sender].push(Deposits({amount: _amount, swapIndex: _swapIndex}));

    emit TokensDeposited(msg.sender, _amount);
  }

  /// @inheritdoc ISwapperV2
  function swap() external payable override onlyOwner nonReentrant {
    address[] memory path = _constructTokenPath();

    uint256 _totalDeposited = _getTokenBalance(DEPOSITED_TOKEN);
    uint256[] memory amounts;

    if (DEPOSITED_TOKEN == address(0)) {
      // swapping ETH -> token
      amounts = ROUTER.swapExactETHForTokens{value: _totalDeposited}(0, path, address(this), block.timestamp);
    } else {
      // Approve the router to spend the deposited tokens
      IERC20(DEPOSITED_TOKEN).approve(address(ROUTER), _totalDeposited);

      if (SWAPPED_TOKEN == address(0)) {
        // Swapping token -> ETH
        amounts = ROUTER.swapExactTokensForETH(
          _totalDeposited,
          0, // Note: min amount out should be passed in as arg
          path,
          address(this),
          block.timestamp
        );
      } else {
        // Swapping token -> token
        amounts = ROUTER.swapExactTokensForTokens(
          _totalDeposited,
          0, // Note: min amount out should be passed in as arg
          path,
          address(this),
          block.timestamp
        );
      }
    }

    uint256 _totalSwapped = amounts[1];

    // Store the swap rate information
    _swaps[_swapIndex] = SwapRateInfo({totalDeposited: _totalDeposited, totalSwapped: _totalSwapped});

    // Increment the swap index
    _swapIndex++;

    emit TokensSwapped(_totalDeposited, _totalSwapped);
  }

  /// @inheritdoc ISwapperV2
  function withdrawDeposit() external nonReentrant {
    Deposits[] storage _deposits = _userDeposits[msg.sender];
    uint256 _withdrawableAmount = 0;

    uint256 i = 0;
    while (i < _deposits.length) {
      if (_deposits[i].swapIndex >= _swapIndex) {
        _withdrawableAmount += _deposits[i].amount;

        // Remove the element by swapping with the last and popping
        _deposits[i] = _deposits[_deposits.length - 1];
        _deposits.pop();
        // Do not increment i since the new item at i needs to be checked
      } else {
          i++;
      }
    }

    if (_withdrawableAmount == 0) revert Swapper_NoTokensToWithdraw();

    // Withdraw the tokens
    if (DEPOSITED_TOKEN == address(0)) {
      payable(msg.sender).transfer(_withdrawableAmount);
    } else {
      IERC20(DEPOSITED_TOKEN).safeTransfer(msg.sender, _withdrawableAmount);
    }

    // Emit the event
    emit DepositWithdrawn(msg.sender, _withdrawableAmount);
  }

  /// @inheritdoc ISwapperV2
  function withdraw() external nonReentrant {
    // Get the deposits for the user
    uint256 _withdrawableAmount = _getSwapTokenAmount(msg.sender);

    if (_withdrawableAmount == 0) revert Swapper_NoTokensToWithdraw();

    // Delete the deposits for the user
    delete _userDeposits[msg.sender];

    // Withdraw the tokens
    if (SWAPPED_TOKEN == address(0)) {
      payable(msg.sender).transfer(_withdrawableAmount);
    } else {
      IERC20(SWAPPED_TOKEN).safeTransfer(msg.sender, _withdrawableAmount);
    }

    // Emit the event
    emit SwappedTokensWithdrawn(msg.sender, _withdrawableAmount);
  }

  /// @inheritdoc ISwapperV2
  function emergencyWithdraw(address token, uint256 amount) external onlyOwner {
    if (amount == 0) revert Swapper_NoTokensToWithdraw();

    if (_getTokenBalance(token) < amount) {
      revert Swapper_NotEnoughLiquidity();
    }

    if (token == address(0)) {
      payable(msg.sender).transfer(amount);
    } else {
      IERC20(token).safeTransfer(msg.sender, amount);
    }
    emit EmergencyWithdraw(msg.sender, token, amount);
  }

  /*///////////////////////////////////////////////////////////////
                            Public Functions
    //////////////////////////////////////////////////////////////*/

  /// @inheritdoc ISwapperV2
  function getSwapTokenAmount(address _user) public view returns (uint256) {
    return _getSwapTokenAmount(_user);
  }

  /// @inheritdoc ISwapperV2
  function getSwapIndex() public view returns (uint256) {
    return _swapIndex;
  }

  /// @inheritdoc ISwapperV2
  function getSwapRateInfo(uint256 _index) public view returns (SwapRateInfo memory) {
    return _swaps[_index];
  }

  /// @inheritdoc ISwapperV2
  function getDeposits(address _user) public view returns (Deposits[] memory) {
    return _userDeposits[_user];
  }

  /*///////////////////////////////////////////////////////////////
                            Internal Functions
    //////////////////////////////////////////////////////////////*/

  /**
   * @notice Gets the swap token amount for a user
   * @param _user The address of the user
   * @return _withdrawableAmount The amount of tokens the user is entitled to withdraw
   */
  function _getSwapTokenAmount(address _user) internal view returns (uint256 _withdrawableAmount) {
    Deposits[] memory _deposits = _userDeposits[_user];
    uint256 _totalDeposits = _deposits.length;

    for (uint256 i = 0; i < _totalDeposits; i++) {
      SwapRateInfo memory _swapRateInfo = _swaps[_deposits[i].swapIndex];
      _withdrawableAmount += _deposits[i].amount * _swapRateInfo.totalSwapped / _swapRateInfo.totalDeposited;
    }
  }

  /**
   * @notice Gets the token balance of the contract
   * @param _token The address of the token
   * @return The balance of the token
   */
  function _getTokenBalance(address _token) internal view returns (uint256) {
    if (_token == address(0)) {
      return address(this).balance;
    } else {
      return IERC20(_token).balanceOf(address(this));
    }
  }

  /**
   * @notice Constructs the token path for the swap
   * @return path The token path
   */
  function _constructTokenPath() internal view returns (address[] memory path) {
    path = new address[](2);

    if (DEPOSITED_TOKEN == address(0)) {
      path[0] = ROUTER.WETH();
    } else {
      path[0] = DEPOSITED_TOKEN;
    }

    if (SWAPPED_TOKEN == address(0)) {
      path[1] = ROUTER.WETH();
    } else {
      path[1] = SWAPPED_TOKEN;
    }
  }
}
