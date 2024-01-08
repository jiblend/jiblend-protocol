// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.10;

import "./ErrorReporter.sol";
import "./ComptrollerStorage.sol";
import "./Comptroller.sol";

/**
 * This contract is a placeholder for typechain to be attach.
 */
contract UnitrollerComptroller is
    UnitrollerAdminStorage,
    ComptrollerErrorReporter,
    Comptroller
{
    event NewPendingImplementation(
        address oldPendingImplementation,
        address newPendingImplementation
    );

    event NewImplementation(
        address oldImplementation,
        address newImplementation
    );

    event NewPendingAdmin(address oldPendingAdmin, address newPendingAdmin);

    event NewAdmin(address oldAdmin, address newAdmin);

    constructor() public {}

    /*** Admin Functions ***/
    function _setPendingImplementation(
        address newPendingImplementation
    ) public returns (uint) {}

    function _acceptImplementation() public returns (uint) {}

    function _setPendingAdmin(address newPendingAdmin) public returns (uint) {}

    function _acceptAdmin() public returns (uint) {}

    fallback() external payable {}
}
