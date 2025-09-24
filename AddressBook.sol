// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/access/Ownable.sol";

/// @title AddressBook Contract
contract AddressBook is Ownable {
    /// @notice Error thrown when a contact is not found
    error ContactNotFound(uint id);

    /// @notice Contact structure
    struct Contact {
        uint id;
        string firstName;
        string lastName;
        uint[] phoneNumbers;
        bool exists; // used to track deleted contacts
    }

    /// @notice Mapping from contact ID to Contact
    mapping(uint => Contact) private contacts;
    /// @notice Track all contact IDs
    uint[] private contactIds;
    /// @notice Auto-incrementing ID counter
    uint private nextId = 1;

    /// @notice Constructor - sets initial owner
    constructor(address initialOwner) Ownable(initialOwner) {}

    /// @notice Add a new contact (only owner)
    function addContact(
        string memory _firstName,
        string memory _lastName,
        uint[] memory _phoneNumbers
    ) external onlyOwner {
        uint id = nextId;
        contacts[id] = Contact({
            id: id,
            firstName: _firstName,
            lastName: _lastName,
            phoneNumbers: _phoneNumbers,
            exists: true
        });
        contactIds.push(id);
        nextId++;
    }

    /// @notice Delete a contact by ID (only owner)
    function deleteContact(uint _id) external onlyOwner {
        if (!contacts[_id].exists) {
            revert ContactNotFound(_id);
        }
        contacts[_id].exists = false;
    }

    /// @notice Get a contact by ID
    function getContact(uint _id) external view returns (Contact memory) {
        if (!contacts[_id].exists) {
            revert ContactNotFound(_id);
        }
        return contacts[_id];
    }

    /// @notice Get all non-deleted contacts
    function getAllContacts() external view returns (Contact[] memory) {
        uint count = 0;
        for (uint i = 0; i < contactIds.length; i++) {
            if (contacts[contactIds[i]].exists) {
                count++;
            }
        }

        Contact[] memory allContacts = new Contact[](count);
        uint index = 0;
        for (uint i = 0; i < contactIds.length; i++) {
            if (contacts[contactIds[i]].exists) {
                allContacts[index] = contacts[contactIds[i]];
                index++;
            }
        }
        return allContacts;
    }
}