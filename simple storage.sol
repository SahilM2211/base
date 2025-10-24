// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title SimpleStorage
 * @dev A simple smart contract that allows storing and retrieving a string message.
 * This contract is intended to be a basic example for deployment on the Base network.
 */
contract SimpleStorage {
    string private message;

    /**
     * @dev Emitted when the message is updated.
     * @param newMessage The new message that was set.
     */
    event MessageChanged(string newMessage);

    /**
     * @dev Sets the initial message when the contract is deployed.
     * @param initialMessage The initial message to store in the contract.
     */
    constructor(string memory initialMessage) {
        message = initialMessage;
    }

    /**
     * @dev Updates the message stored in the contract.
     * @param newMessage The new message to be stored.
     */
    function setMessage(string memory newMessage) public {
        message = newMessage;
        emit MessageChanged(newMessage);
    }

    /**
     * @dev Retrieves the current message stored in the contract.
     * @return The current message.
     */
    function getMessage() public view returns (string memory) {
        return message;
    }
}

