// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.10;

import "./JToken.sol";

abstract contract PriceOracle {
  /// @notice Indicator that this is a PriceOracle contract (for inspection)
  bool public constant isPriceOracle = true;

  /**
   * @notice Get the underlying price of a jToken asset
   * @param jToken The jToken to get the underlying price of
   * @return The underlying asset price mantissa (scaled by 1e18).
   *  Zero means the price is unavailable.
   */
  function getUnderlyingPrice(JToken jToken) external view virtual returns (uint);

  /**
   * @notice Get the price of a specific asset
   * @param asset The asset to get the price of
   * @return The asset price mantissa (scaled by 1e18).
   *  Zero means the price is unavailable.
   */
  function getAssetPrice(address asset) external view virtual returns (uint);
}
