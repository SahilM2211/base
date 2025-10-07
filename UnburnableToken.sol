// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "hardhat/console.sol";

contract UnburnableToken {
    
    // Custom errors for clarity and gas efficiency
    error TokensClaimed();
    error AllTokensClaimed();
    error UnsafeTransfer(address _to);

    // --- State Variables ---
    mapping(address => uint) public balances;
    mapping(address => bool) private hasClaimed;

    uint public totalSupply;
    uint public totalClaimed;

    // --- Constructor ---
    constructor() {
        totalSupply = 100_000_000;
    }

    // --- Functions ---
    
    /// @dev Allows a wallet to claim a one-time allocation of 1000 tokens.
    function claim() public {
        if (hasClaimed[msg.sender]) {
            revert TokensClaimed();
        }

        if (totalClaimed + 1000 > totalSupply) {
            revert AllTokensClaimed();
        }

        balances[msg.sender] += 1000;
        totalClaimed += 1000;
        hasClaimed[msg.sender] = true;
    }

    /// @dev Transfers tokens safely from the sender to a specified address.
    /// @param _to The recipient's address.
    /// @param _amount The amount of tokens to transfer.
    function safeTransfer(address _to, uint _amount) public {
        // Check for the zero address and a positive ETH balance
        if (_to == address(0) || _to.balance == 0) {
            revert UnsafeTransfer(_to);
        }

        // Standard checks for token transfers
        require(balances[msg.sender] >= _amount, "Insufficient balance");
        
        balances[msg.sender] -= _amount;
        balances[_to] += _amount;
    }
}