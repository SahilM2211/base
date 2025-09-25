// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "./AddressBook.sol";

/// @title AddressBookFactory Contract
contract AddressBookFactory {
    /// @notice Deploy a new AddressBook contract and assign caller as owner
    function deploy() external returns (address) {
        AddressBook newBook = new AddressBook(msg.sender);
        return address(newBook);
    }
}