// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

/**
 * @title Swapper Contract
 * @author thelostone-mc
 * @notice Simple swapper contract to pool, swap and withdraw tokens
 */
interface ISwapperV2 {

  /**
   * @notice Struct to track deposit information
   * @param amount The amount of tokens deposited
   * @param swapIndex The index of the swap this deposit is for
   */
  struct Deposits {
    uint256 amount;
    uint256 swapIndex;
  }

  /**
   * @notice Struct to track swap rate information
   * @param totalDeposited The total amount of tokens deposited
   * @param totalSwapped The total amount of tokens swapped
   */
  struct SwapRateInfo {
    uint256 totalDeposited;
    uint256 totalSwapped;
  }

  /*///////////////////////////////////////////////////////////////
                            Events
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Emitted when a user deposits tokens
   * @param user The address of the user depositing tokens
   * @param amount The amount of tokens deposited
   */
  event TokensDeposited(address indexed user, uint256 amount);

  /**
   * @notice Emitted when tokens are swapped
   */
  event TokensSwapped(uint256 totalDeposited, uint256 totalSwapped);

  /**
   * @notice Emitted when a user withdraws their tokens
   * @param user The address of the user withdrawing tokens
   * @param amount The amount of tokens withdrawn
   */
  event SwappedTokensWithdrawn(address indexed user, uint256 amount);

  /**
   * @notice Emitted when a user withdraws their deposit
   * @param user The address of the user withdrawing their deposit
   * @param amount The amount of tokens withdrawn
   */
  event DepositWithdrawn(address indexed user, uint256 amount);

  /**
   * @notice Emitted when emergency withdraw is called
   * @param user The address of the user withdrawing tokens
   * @param token The address of the token withdrawn
   * @param amount The amount of tokens withdrawn
   */
  event EmergencyWithdraw(address indexed user, address indexed token, uint256 amount);

  /*///////////////////////////////////////////////////////////////
                            Errors
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Thrown if amount of tokens deposited is 0
   */
  error Swapper_InvalidAmount();

  /**
   * @notice Thrown if caller has no tokens to withdraw
   */
  error Swapper_NoTokensToWithdraw();

  /**
   * @notice Thrown if amount of tokens deposited is not correct
   */
  error Swapper_AmountMismatch();

  /**
   * @notice Thrown if swap has already been executed
   */
  error Swapper_SwapAlreadyExecuted();

  /**
   * @notice Thrown if swap has not been executed
   */
  error Swapper_SwapNotExecuted();

  /**
   * @notice Thrown if user has already withdrawn their tokens
   */
  error Swapper_AlreadyWithdrawn();

  /**
   * @notice Thrown if there is not enough liquidity
   */
  error Swapper_NotEnoughLiquidity();

  /**
   * @notice Thrown if tokens are the same
   */
  error Swapper_InvalidTokens();

  /*///////////////////////////////////////////////////////////////
                            VARIABLES
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice The address of the token deposited for swapping
   */
  function DEPOSITED_TOKEN() external view returns (address);

  /**
   * @notice The address of the token swapped to
   */
  function SWAPPED_TOKEN() external view returns (address);


  /*///////////////////////////////////////////////////////////////
                            Logic
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Allows users to deposit tokens for swapping
   * @param _amount The amount of fromToken to deposit
   */
  function deposit(uint256 _amount) external payable;

  /**
   * @notice Executes the swap of all deposited tokens
   */
  function swap() external payable;

  /**
   * @notice Allows users to withdraw their swapped tokens
   */
  function withdraw() external;

  /**
   * @notice Allows users to withdraw their deposit
   */
  function withdrawDeposit() external;

  /**
   * @notice Get the amount of tokens a user is entitled to
   * @param _user The address of the user
   * @return The amount of tokens the user is entitled to
   */
  function getSwapTokenAmount(address _user) external view returns (uint256);

  /**
   * @notice Emergency withdraw function to withdraw tokens from the contract
   * @param token The address of the token to withdraw
   * @param amount The amount of tokens to withdraw
   */
  function emergencyWithdraw(address token, uint256 amount) external;
}
