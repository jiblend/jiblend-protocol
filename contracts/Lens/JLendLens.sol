// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.10;

import "../JErc20.sol";
import "../JToken.sol";
import "../PriceOracle.sol";
import "../EIP20Interface.sol";
import "../Governance/GovernorAlpha.sol";
import "../Governance/JLEND.sol";

interface ComptrollerLensInterface {
  function markets(address) external view returns (bool, uint);

  function oracle() external view returns (PriceOracle);

  function getAccountLiquidity(address) external view returns (uint, uint, uint);

  function getAssetsIn(address) external view returns (JToken[] memory);

  function claimJLend(address) external;

  function jLendAccrued(address) external view returns (uint);

  function jLendSpeeds(address) external view returns (uint);

  function jLendSupplySpeeds(address) external view returns (uint);

  function jLendBorrowSpeeds(address) external view returns (uint);

  function borrowCaps(address) external view returns (uint);
}

interface GovernorBravoInterface {
  struct Receipt {
    bool hasVoted;
    uint8 support;
    uint96 votes;
  }
  struct Proposal {
    uint id;
    address proposer;
    uint eta;
    uint startBlock;
    uint endBlock;
    uint forVotes;
    uint againstVotes;
    uint abstainVotes;
    bool canceled;
    bool executed;
  }

  function getActions(
    uint proposalId
  )
    external
    view
    returns (
      address[] memory targets,
      uint[] memory values,
      string[] memory signatures,
      bytes[] memory calldatas
    );

  function proposals(uint proposalId) external view returns (Proposal memory);

  function getReceipt(uint proposalId, address voter) external view returns (Receipt memory);
}

contract JLendLens {
  struct JTokenMetadata {
    address jToken;
    uint exchangeRateCurrent;
    uint supplyRatePerBlock;
    uint borrowRatePerBlock;
    uint reserveFactorMantissa;
    uint totalBorrows;
    uint totalReserves;
    uint totalSupply;
    uint totalCash;
    bool isListed;
    uint collateralFactorMantissa;
    address underlyingAssetAddress;
    uint jTokenDecimals;
    uint underlyingDecimals;
    uint jLendSupplySpeed;
    uint jLendBorrowSpeed;
    uint borrowCap;
  }

  function getJLendSpeeds(ComptrollerLensInterface comptroller, JToken jToken) internal returns (uint, uint) {
    // Getting jLend speeds is gnarly due to not every network having the
    // split jLend speeds from Proposal 62 and other networks don't even
    // have jLend speeds.
    uint jLendSupplySpeed = 0;
    (bool jLendSupplySpeedSuccess, bytes memory jLendSupplySpeedReturnData) = address(comptroller).call(
      abi.encodePacked(comptroller.jLendSupplySpeeds.selector, abi.encode(address(jToken)))
    );
    if (jLendSupplySpeedSuccess) {
      jLendSupplySpeed = abi.decode(jLendSupplySpeedReturnData, (uint));
    }

    uint jLendBorrowSpeed = 0;
    (bool jLendBorrowSpeedSuccess, bytes memory jLendBorrowSpeedReturnData) = address(comptroller).call(
      abi.encodePacked(comptroller.jLendBorrowSpeeds.selector, abi.encode(address(jToken)))
    );
    if (jLendBorrowSpeedSuccess) {
      jLendBorrowSpeed = abi.decode(jLendBorrowSpeedReturnData, (uint));
    }

    // If the split jLend speeds call doesn't work, try the  oldest non-spit version.
    if (!jLendSupplySpeedSuccess || !jLendBorrowSpeedSuccess) {
      (bool jLendSpeedSuccess, bytes memory jLendSpeedReturnData) = address(comptroller).call(
        abi.encodePacked(comptroller.jLendSpeeds.selector, abi.encode(address(jToken)))
      );
      if (jLendSpeedSuccess) {
        jLendSupplySpeed = jLendBorrowSpeed = abi.decode(jLendSpeedReturnData, (uint));
      }
    }
    return (jLendSupplySpeed, jLendBorrowSpeed);
  }

  function jTokenMetadata(JToken jToken) public returns (JTokenMetadata memory) {
    uint exchangeRateCurrent = jToken.exchangeRateCurrent();
    ComptrollerLensInterface comptroller = ComptrollerLensInterface(address(jToken.comptroller()));
    (bool isListed, uint collateralFactorMantissa) = comptroller.markets(address(jToken));
    address underlyingAssetAddress;
    uint underlyingDecimals;

    if (compareStrings(jToken.symbol(), "jJBC")) {
      underlyingAssetAddress = address(0);
      underlyingDecimals = 18;
    } else {
      JErc20 cErc20 = JErc20(address(jToken));
      underlyingAssetAddress = cErc20.underlying();
      underlyingDecimals = EIP20Interface(cErc20.underlying()).decimals();
    }

    (uint jLendSupplySpeed, uint jLendBorrowSpeed) = getJLendSpeeds(comptroller, jToken);

    uint borrowCap = 0;
    (bool borrowCapSuccess, bytes memory borrowCapReturnData) = address(comptroller).call(
      abi.encodePacked(comptroller.borrowCaps.selector, abi.encode(address(jToken)))
    );
    if (borrowCapSuccess) {
      borrowCap = abi.decode(borrowCapReturnData, (uint));
    }

    return
      JTokenMetadata({
        jToken: address(jToken),
        exchangeRateCurrent: exchangeRateCurrent,
        supplyRatePerBlock: jToken.supplyRatePerBlock(),
        borrowRatePerBlock: jToken.borrowRatePerBlock(),
        reserveFactorMantissa: jToken.reserveFactorMantissa(),
        totalBorrows: jToken.totalBorrows(),
        totalReserves: jToken.totalReserves(),
        totalSupply: jToken.totalSupply(),
        totalCash: jToken.getCash(),
        isListed: isListed,
        collateralFactorMantissa: collateralFactorMantissa,
        underlyingAssetAddress: underlyingAssetAddress,
        jTokenDecimals: jToken.decimals(),
        underlyingDecimals: underlyingDecimals,
        jLendSupplySpeed: jLendSupplySpeed,
        jLendBorrowSpeed: jLendBorrowSpeed,
        borrowCap: borrowCap
      });
  }

  function jTokenMetadataAll(JToken[] calldata jTokens) external returns (JTokenMetadata[] memory) {
    uint jTokenCount = jTokens.length;
    JTokenMetadata[] memory res = new JTokenMetadata[](jTokenCount);
    for (uint i = 0; i < jTokenCount; i++) {
      res[i] = jTokenMetadata(jTokens[i]);
    }
    return res;
  }

  struct JTokenBalances {
    address jToken;
    uint balanceOf;
    uint borrowBalanceCurrent;
    uint balanceOfUnderlying;
    uint tokenBalance;
    uint tokenAllowance;
  }

  function jTokenBalances(JToken jToken, address payable account) public returns (JTokenBalances memory) {
    uint balanceOf = jToken.balanceOf(account);
    uint borrowBalanceCurrent = jToken.borrowBalanceCurrent(account);
    uint balanceOfUnderlying = jToken.balanceOfUnderlying(account);
    uint tokenBalance;
    uint tokenAllowance;

    if (compareStrings(jToken.symbol(), "jJBC")) {
      tokenBalance = account.balance;
      tokenAllowance = account.balance;
    } else {
      JErc20 cErc20 = JErc20(address(jToken));
      EIP20Interface underlying = EIP20Interface(cErc20.underlying());
      tokenBalance = underlying.balanceOf(account);
      tokenAllowance = underlying.allowance(account, address(jToken));
    }

    return
      JTokenBalances({
        jToken: address(jToken),
        balanceOf: balanceOf,
        borrowBalanceCurrent: borrowBalanceCurrent,
        balanceOfUnderlying: balanceOfUnderlying,
        tokenBalance: tokenBalance,
        tokenAllowance: tokenAllowance
      });
  }

  function jTokenBalancesAll(
    JToken[] calldata jTokens,
    address payable account
  ) external returns (JTokenBalances[] memory) {
    uint jTokenCount = jTokens.length;
    JTokenBalances[] memory res = new JTokenBalances[](jTokenCount);
    for (uint i = 0; i < jTokenCount; i++) {
      res[i] = jTokenBalances(jTokens[i], account);
    }
    return res;
  }

  struct JTokenUnderlyingPrice {
    address jToken;
    uint underlyingPrice;
  }

  function jTokenUnderlyingPrice(JToken jToken) public returns (JTokenUnderlyingPrice memory) {
    ComptrollerLensInterface comptroller = ComptrollerLensInterface(address(jToken.comptroller()));
    PriceOracle priceOracle = comptroller.oracle();

    return
      JTokenUnderlyingPrice({
        jToken: address(jToken),
        underlyingPrice: priceOracle.getUnderlyingPrice(jToken)
      });
  }

  function jTokenUnderlyingPriceAll(
    JToken[] calldata jTokens
  ) external returns (JTokenUnderlyingPrice[] memory) {
    uint jTokenCount = jTokens.length;
    JTokenUnderlyingPrice[] memory res = new JTokenUnderlyingPrice[](jTokenCount);
    for (uint i = 0; i < jTokenCount; i++) {
      res[i] = jTokenUnderlyingPrice(jTokens[i]);
    }
    return res;
  }

  struct AccountLimits {
    JToken[] markets;
    uint liquidity;
    uint shortfall;
  }

  function getAccountLimits(
    ComptrollerLensInterface comptroller,
    address account
  ) public returns (AccountLimits memory) {
    (uint errorCode, uint liquidity, uint shortfall) = comptroller.getAccountLiquidity(account);
    require(errorCode == 0);

    return
      AccountLimits({markets: comptroller.getAssetsIn(account), liquidity: liquidity, shortfall: shortfall});
  }

  struct GovReceipt {
    uint proposalId;
    bool hasVoted;
    bool support;
    uint96 votes;
  }

  function getGovReceipts(
    GovernorAlpha governor,
    address voter,
    uint[] memory proposalIds
  ) public view returns (GovReceipt[] memory) {
    uint proposalCount = proposalIds.length;
    GovReceipt[] memory res = new GovReceipt[](proposalCount);
    for (uint i = 0; i < proposalCount; i++) {
      GovernorAlpha.Receipt memory receipt = governor.getReceipt(proposalIds[i], voter);
      res[i] = GovReceipt({
        proposalId: proposalIds[i],
        hasVoted: receipt.hasVoted,
        support: receipt.support,
        votes: receipt.votes
      });
    }
    return res;
  }

  struct GovBravoReceipt {
    uint proposalId;
    bool hasVoted;
    uint8 support;
    uint96 votes;
  }

  function getGovBravoReceipts(
    GovernorBravoInterface governor,
    address voter,
    uint[] memory proposalIds
  ) public view returns (GovBravoReceipt[] memory) {
    uint proposalCount = proposalIds.length;
    GovBravoReceipt[] memory res = new GovBravoReceipt[](proposalCount);
    for (uint i = 0; i < proposalCount; i++) {
      GovernorBravoInterface.Receipt memory receipt = governor.getReceipt(proposalIds[i], voter);
      res[i] = GovBravoReceipt({
        proposalId: proposalIds[i],
        hasVoted: receipt.hasVoted,
        support: receipt.support,
        votes: receipt.votes
      });
    }
    return res;
  }

  struct GovProposal {
    uint proposalId;
    address proposer;
    uint eta;
    address[] targets;
    uint[] values;
    string[] signatures;
    bytes[] calldatas;
    uint startBlock;
    uint endBlock;
    uint forVotes;
    uint againstVotes;
    bool canceled;
    bool executed;
  }

  function setProposal(GovProposal memory res, GovernorAlpha governor, uint proposalId) internal view {
    (
      ,
      address proposer,
      uint eta,
      uint startBlock,
      uint endBlock,
      uint forVotes,
      uint againstVotes,
      bool canceled,
      bool executed
    ) = governor.proposals(proposalId);
    res.proposalId = proposalId;
    res.proposer = proposer;
    res.eta = eta;
    res.startBlock = startBlock;
    res.endBlock = endBlock;
    res.forVotes = forVotes;
    res.againstVotes = againstVotes;
    res.canceled = canceled;
    res.executed = executed;
  }

  function getGovProposals(
    GovernorAlpha governor,
    uint[] calldata proposalIds
  ) external view returns (GovProposal[] memory) {
    GovProposal[] memory res = new GovProposal[](proposalIds.length);
    for (uint i = 0; i < proposalIds.length; i++) {
      (
        address[] memory targets,
        uint[] memory values,
        string[] memory signatures,
        bytes[] memory calldatas
      ) = governor.getActions(proposalIds[i]);
      res[i] = GovProposal({
        proposalId: 0,
        proposer: address(0),
        eta: 0,
        targets: targets,
        values: values,
        signatures: signatures,
        calldatas: calldatas,
        startBlock: 0,
        endBlock: 0,
        forVotes: 0,
        againstVotes: 0,
        canceled: false,
        executed: false
      });
      setProposal(res[i], governor, proposalIds[i]);
    }
    return res;
  }

  struct GovBravoProposal {
    uint proposalId;
    address proposer;
    uint eta;
    address[] targets;
    uint[] values;
    string[] signatures;
    bytes[] calldatas;
    uint startBlock;
    uint endBlock;
    uint forVotes;
    uint againstVotes;
    uint abstainVotes;
    bool canceled;
    bool executed;
  }

  function setBravoProposal(
    GovBravoProposal memory res,
    GovernorBravoInterface governor,
    uint proposalId
  ) internal view {
    GovernorBravoInterface.Proposal memory p = governor.proposals(proposalId);

    res.proposalId = proposalId;
    res.proposer = p.proposer;
    res.eta = p.eta;
    res.startBlock = p.startBlock;
    res.endBlock = p.endBlock;
    res.forVotes = p.forVotes;
    res.againstVotes = p.againstVotes;
    res.abstainVotes = p.abstainVotes;
    res.canceled = p.canceled;
    res.executed = p.executed;
  }

  function getGovBravoProposals(
    GovernorBravoInterface governor,
    uint[] calldata proposalIds
  ) external view returns (GovBravoProposal[] memory) {
    GovBravoProposal[] memory res = new GovBravoProposal[](proposalIds.length);
    for (uint i = 0; i < proposalIds.length; i++) {
      (
        address[] memory targets,
        uint[] memory values,
        string[] memory signatures,
        bytes[] memory calldatas
      ) = governor.getActions(proposalIds[i]);
      res[i] = GovBravoProposal({
        proposalId: 0,
        proposer: address(0),
        eta: 0,
        targets: targets,
        values: values,
        signatures: signatures,
        calldatas: calldatas,
        startBlock: 0,
        endBlock: 0,
        forVotes: 0,
        againstVotes: 0,
        abstainVotes: 0,
        canceled: false,
        executed: false
      });
      setBravoProposal(res[i], governor, proposalIds[i]);
    }
    return res;
  }

  struct JLendBalanceMetadata {
    uint balance;
    uint votes;
    address delegate;
  }

  function getJLendBalanceMetadata(
    JLEND jLend,
    address account
  ) external view returns (JLendBalanceMetadata memory) {
    return
      JLendBalanceMetadata({
        balance: jLend.balanceOf(account),
        votes: uint256(jLend.getCurrentVotes(account)),
        delegate: jLend.delegates(account)
      });
  }

  struct JLendBalanceMetadataExt {
    uint balance;
    uint votes;
    address delegate;
    uint allocated;
  }

  function getJLendBalanceMetadataExt(
    JLEND jLend,
    ComptrollerLensInterface comptroller,
    address account
  ) external returns (JLendBalanceMetadataExt memory) {
    uint balance = jLend.balanceOf(account);
    comptroller.claimJLend(account);
    uint newBalance = jLend.balanceOf(account);
    uint accrued = comptroller.jLendAccrued(account);
    uint total = add(accrued, newBalance, "sum jLend total");
    uint allocated = sub(total, balance, "sub allocated");

    return
      JLendBalanceMetadataExt({
        balance: balance,
        votes: uint256(jLend.getCurrentVotes(account)),
        delegate: jLend.delegates(account),
        allocated: allocated
      });
  }

  struct JLendVotes {
    uint blockNumber;
    uint votes;
  }

  function getJLendVotes(
    JLEND jLend,
    address account,
    uint32[] calldata blockNumbers
  ) external view returns (JLendVotes[] memory) {
    JLendVotes[] memory res = new JLendVotes[](blockNumbers.length);
    for (uint i = 0; i < blockNumbers.length; i++) {
      res[i] = JLendVotes({
        blockNumber: uint256(blockNumbers[i]),
        votes: uint256(jLend.getPriorVotes(account, blockNumbers[i]))
      });
    }
    return res;
  }

  function compareStrings(string memory a, string memory b) internal pure returns (bool) {
    return (keccak256(abi.encodePacked((a))) == keccak256(abi.encodePacked((b))));
  }

  function add(uint a, uint b, string memory errorMessage) internal pure returns (uint) {
    uint c = a + b;
    require(c >= a, errorMessage);
    return c;
  }

  function sub(uint a, uint b, string memory errorMessage) internal pure returns (uint) {
    require(b <= a, errorMessage);
    uint c = a - b;
    return c;
  }
}
