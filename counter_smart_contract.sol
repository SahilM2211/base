// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title Counter
 * @dev A simple smart contract that allows for incrementing and decrementing a counter.
 * This contract serves as another basic example for deployment on the Base network.
 */
contract Counter {
    uint256 public count;

    /**
     * @dev Emitted when the count is changed.
     * @param newCount The new value of the counter.
     */
    event CountChanged(uint256 newCount);

    /**
     * @dev Sets the initial count when the contract is deployed.
     * @param initialCount The initial value for the counter.
     */
    constructor(uint256 initialCount) {
        count = initialCount;
    }

    /**
     * @dev Increments the counter by 1.
     */
    function increment() public {
        count++;
        emit CountChanged(count);
    }

    /**
     * @dev Decrements the counter by 1.
     * It will revert the transaction if the count is already 0 to prevent underflow.
     */
    function decrement() public {
        require(count > 0, "Counter: Cannot decrement below zero.");
        count--;
        emit CountChanged(count);
    }

    /**
     * @dev Retrieves the current count.
     * @return The current value of the counter.
     */
    function getCount() public view returns (uint256) {
        return count;
    }
}