// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.10;

abstract contract ComptrollerInterface {
  /// @notice Indicator that this is a Comptroller contract (for inspection)
  bool public constant isComptroller = true;

  /*** Assets You Are In ***/

  function enterMarkets(address[] calldata jTokens) external virtual returns (uint[] memory);

  function exitMarket(address jToken) external virtual returns (uint);

  /*** Policy Hooks ***/

  function mintAllowed(address jToken, address minter, uint mintAmount) external virtual returns (uint);

  function mintVerify(address jToken, address minter, uint mintAmount, uint mintTokens) external virtual;

  function redeemAllowed(address jToken, address redeemer, uint redeemTokens) external virtual returns (uint);

  function redeemVerify(
    address jToken,
    address redeemer,
    uint redeemAmount,
    uint redeemTokens
  ) external virtual;

  function borrowAllowed(address jToken, address borrower, uint borrowAmount) external virtual returns (uint);

  function borrowVerify(address jToken, address borrower, uint borrowAmount) external virtual;

  function repayBorrowAllowed(
    address jToken,
    address payer,
    address borrower,
    uint repayAmount
  ) external virtual returns (uint);

  function repayBorrowVerify(
    address jToken,
    address payer,
    address borrower,
    uint repayAmount,
    uint borrowerIndex
  ) external virtual;

  function liquidateBorrowAllowed(
    address jTokenBorrowed,
    address jTokenCollateral,
    address liquidator,
    address borrower,
    uint repayAmount
  ) external virtual returns (uint);

  function liquidateBorrowVerify(
    address jTokenBorrowed,
    address jTokenCollateral,
    address liquidator,
    address borrower,
    uint repayAmount,
    uint seizeTokens
  ) external virtual;

  function seizeAllowed(
    address jTokenCollateral,
    address jTokenBorrowed,
    address liquidator,
    address borrower,
    uint seizeTokens
  ) external virtual returns (uint);

  function seizeVerify(
    address jTokenCollateral,
    address jTokenBorrowed,
    address liquidator,
    address borrower,
    uint seizeTokens
  ) external virtual;

  function transferAllowed(
    address jToken,
    address src,
    address dst,
    uint transferTokens
  ) external virtual returns (uint);

  function transferVerify(address jToken, address src, address dst, uint transferTokens) external virtual;

  /*** Liquidity/Liquidation Calculations ***/

  function liquidateCalculateSeizeTokens(
    address jTokenBorrowed,
    address jTokenCollateral,
    uint repayAmount
  ) external view virtual returns (uint, uint);
}
