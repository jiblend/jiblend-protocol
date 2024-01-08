// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.10;

import "./PriceOracle.sol";
import "./JErc20.sol";

contract SimplePriceOracle is PriceOracle {
  mapping(address => uint) prices;
  event PricePosted(
    address asset,
    uint previousPriceMantissa,
    uint requestedPriceMantissa,
    uint newPriceMantissa
  );

  function _getUnderlyingAddress(JToken jToken) private view returns (address) {
    address asset;
    if (compareStrings(jToken.symbol(), "jJBC")) {
      asset = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    } else {
      asset = address(JErc20(address(jToken)).underlying());
    }
    return asset;
  }

  function getUnderlyingPrice(JToken jToken) public view override returns (uint) {
    return prices[_getUnderlyingAddress(jToken)];
  }

  // v1 price oracle interface for use as backing of proxy
  function getAssetPrice(address asset) public view override returns (uint) {
    return prices[asset];
  }

  function setUnderlyingPrice(JToken jToken, uint underlyingPriceMantissa) public {
    address asset = _getUnderlyingAddress(jToken);
    emit PricePosted(asset, prices[asset], underlyingPriceMantissa, underlyingPriceMantissa);
    prices[asset] = underlyingPriceMantissa;
  }

  function setDirectPrice(address asset, uint price) public {
    emit PricePosted(asset, prices[asset], price, price);
    prices[asset] = price;
  }

  function compareStrings(string memory a, string memory b) internal pure returns (bool) {
    return (keccak256(abi.encodePacked((a))) == keccak256(abi.encodePacked((b))));
  }
}
