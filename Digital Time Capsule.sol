// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title PersonalTimeLock
 * @dev A simple, strict savings vault.
 * You deposit funds and set a time. The funds are frozen until that time.
 * * REAL WORLD USE: Forced savings, trust funds for kids, or "diamond hands" for assets.
 * DEPLOYMENT: Easiest possible. No arguments required.
 */
contract PersonalTimeLock {

    struct LockBox {
        uint256 balance;
        uint256 unlockTime; // Unix timestamp
    }

    // Mapping from user address to their personal LockBox
    mapping(address => LockBox) public vaults;

    event FundsLocked(address indexed user, uint256 amount, uint256 unlockTime);
    event FundsWithdrawn(address indexed user, uint256 amount);
    event LockExtended(address indexed user, uint256 newUnlockTime);

    /**
     * @dev Constructor is empty. Easy deployment!
     */
    constructor() {}

    /**
     * @dev Deposit ETH and lock it until a specific timestamp.
     * @param _unlockTime The Unix timestamp when funds become available.
     */
    function lockFunds(uint256 _unlockTime) public payable {
        require(msg.value > 0, "You must deposit some ETH.");
        require(_unlockTime > block.timestamp, "Unlock time must be in the future.");

        LockBox storage box = vaults[msg.sender];

        // If they already have a lock, we ensure they don't accidentally 
        // reduce the time. They can only extend it or keep it the same.
        if (box.balance > 0) {
            require(_unlockTime >= box.unlockTime, "Cannot shorten existing lock time.");
        }

        box.balance += msg.value;
        box.unlockTime = _unlockTime;

        emit FundsLocked(msg.sender, msg.value, _unlockTime);
    }

    /**
     * @dev Withdraw all funds IF the unlock time has passed.
     */
    function withdraw() public {
        LockBox storage box = vaults[msg.sender];
        
        require(box.balance > 0, "No funds to withdraw.");
        require(block.timestamp >= box.unlockTime, "Funds are still locked! Wait longer.");

        uint256 amount = box.balance;
        box.balance = 0;

        (bool success, ) = msg.sender.call{value: amount}("");
        require(success, "Transfer failed.");

        emit FundsWithdrawn(msg.sender, amount);
    }

    /**
     * @dev Add more funds to an existing lock without changing the time.
     */
    function addToLock() public payable {
        require(msg.value > 0, "Must send ETH");
        LockBox storage box = vaults[msg.sender];
        require(box.balance > 0, "No active lock found. Use lockFunds first.");

        box.balance += msg.value;
        emit FundsLocked(msg.sender, msg.value, box.unlockTime);
    }

    // --- View Functions ---

    function getMyVault() public view returns (uint256 amount, uint256 unlockTime, uint256 timeRemaining) {
        LockBox memory box = vaults[msg.sender];
        
        uint256 remaining = 0;
        if (box.unlockTime > block.timestamp) {
            remaining = box.unlockTime - block.timestamp;
        }

        return (box.balance, box.unlockTime, remaining);
    }
}