// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.10;

import "./JEther.sol";

/**
 * @title JLEND's Maximillion Contract
 * @author JLEND
 */
contract Maximillion {
  /**
   * @notice The default jEther market to repay in
   */
  JEther public jEther;

  /**
   * @notice Construct a Maximillion to repay max in a JEther market
   */
  constructor(JEther jEther_) public {
    jEther = jEther_;
  }

  /**
   * @notice msg.sender sends Ether to repay an account's borrow in the jEther market
   * @dev The provided Ether is applied towards the borrow balance, any excess is refunded
   * @param borrower The address of the borrower account to repay on behalf of
   */
  function repayBehalf(address borrower) public payable {
    repayBehalfExplicit(borrower, jEther);
  }

  /**
   * @notice msg.sender sends Ether to repay an account's borrow in a jEther market
   * @dev The provided Ether is applied towards the borrow balance, any excess is refunded
   * @param borrower The address of the borrower account to repay on behalf of
   * @param jEther_ The address of the jEther contract to repay in
   */
  function repayBehalfExplicit(address borrower, JEther jEther_) public payable {
    uint received = msg.value;
    uint borrows = jEther_.borrowBalanceCurrent(borrower);
    if (received > borrows) {
      jEther_.repayBorrowBehalf{value: borrows}(borrower);
      payable(msg.sender).transfer(received - borrows);
    } else {
      jEther_.repayBorrowBehalf{value: received}(borrower);
    }
  }
}
