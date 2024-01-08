// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.10;

import "@pythnetwork/pyth-sdk-solidity/IPyth.sol";
import "@pythnetwork/pyth-sdk-solidity/PythStructs.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "./PriceOracle.sol";
import "./JErc20.sol";
import "./EIP20Interface.sol";

contract ExperimentalPythPriceOracle is Ownable, PriceOracle {
  IPyth pyth;

  mapping(address => uint) prices; // 1e18
  mapping(address => bytes32) priceIds;

  event SetDirectPrice(address asset, uint price);
  event SetPricePythId(address asset, bytes32 priceId);

  constructor(address _pyth) Ownable(msg.sender) {
    pyth = IPyth(_pyth);
  }

  function _getUnderlyingAddress(JToken jToken) private view returns (address) {
    address asset;
    if (compareStrings(jToken.symbol(), "jJBC")) {
      asset = 0x4200000000000000000000000000000000000006; // change this to actual WETH address
    } else {
      asset = address(JErc20(address(jToken)).underlying());
    }
    return asset;
  }

  function getUnderlyingPrice(JToken jToken) public view override returns (uint) {
    address asset = _getUnderlyingAddress(jToken);
    uint price = prices[asset];
    if (priceIds[asset] != bytes32(0)) {
      PythStructs.Price memory currentPythPrice = pyth.getPriceUnsafe(priceIds[asset]);
      price = convertToUint(currentPythPrice, 18 + 18 - EIP20Interface(asset).decimals());
    }
    return price;
  }

  function getAssetPrice(address asset) public view override returns (uint) {
    uint price = prices[asset];
    if (priceIds[asset] != bytes32(0)) {
      PythStructs.Price memory currentPythPrice = pyth.getPriceUnsafe(priceIds[asset]);
      price = convertToUint(currentPythPrice, 18 + 18 - EIP20Interface(asset).decimals());
    }
    return price;
  }

  function setUnderlyingDirectPrice(JToken jToken, uint price) public onlyOwner {
    emit SetDirectPrice(address(jToken), price);
    prices[_getUnderlyingAddress(jToken)] = price;
  }

  function setAssetDirectPrice(address asset, uint price) public onlyOwner {
    emit SetDirectPrice(asset, price);
    prices[asset] = price;
  }

  function setUnderlyingPythPriceId(JToken jToken, bytes32 priceId) public onlyOwner {
    address asset = _getUnderlyingAddress(jToken);
    emit SetPricePythId(address(asset), priceId);
    prices[asset] = 0;
    priceIds[asset] = priceId;
  }

  function setAssetPythPriceId(address asset, bytes32 priceId) public onlyOwner {
    emit SetPricePythId(asset, priceId);
    prices[asset] = 0;
    priceIds[asset] = priceId;
  }

  function compareStrings(string memory a, string memory b) internal pure returns (bool) {
    return (keccak256(abi.encodePacked((a))) == keccak256(abi.encodePacked((b))));
  }

  function convertToUint(
    PythStructs.Price memory price,
    uint8 targetDecimals
  ) internal pure returns (uint256) {
    if (price.price < 0 || price.expo > 0 || price.expo < -255) {
      revert("!P"); // Invalid price
    }

    uint8 priceDecimals = uint8(uint32(-1 * price.expo));

    if (targetDecimals >= priceDecimals) {
      return uint(uint64(price.price)) * 10 ** uint32(targetDecimals - priceDecimals);
    } else {
      return uint(uint64(price.price)) / 10 ** uint32(priceDecimals - targetDecimals);
    }
  }
}
