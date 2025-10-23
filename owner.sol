// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title Owner
 * @dev A simple contract to demonstrate ownership patterns.
 * The address that deploys the contract becomes the owner.
 * Ownership can be transferred to a new address.
 */
contract Owner {
    address public owner;

    /**
     * @dev Emitted when ownership is transferred.
     * @param previousOwner The address of the previous owner.
     * @param newOwner The address of the new owner.
     */
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev A modifier to ensure a function is only called by the owner.
     */
    modifier onlyOwner() {
        require(msg.sender == owner, "Caller is not the owner");
        _;
    }

    /**
     * @dev Sets the contract deployer as the initial owner.
     */
    constructor() {
        owner = msg.sender;
        emit OwnershipTransferred(address(0), owner);
    }

    /**
     * @dev Allows the current owner to transfer ownership of the contract to a new address.
     * @param newOwner The address of the new owner.
     */
    function transferOwnership(address newOwner) public onlyOwner {
        require(newOwner != address(0), "New owner cannot be the zero address");
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    /**
     * @dev A sample function that can only be called by the owner.
     * @return A success message string.
     */
    function ownerOnlyFunction() public view onlyOwner returns (string memory) {
        return "Success! You are the owner.";
    }
}
