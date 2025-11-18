// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

/**
 * @title RevenueSplitter
 * @dev Solves the real-world problem of fairly and automatically splitting
 * revenue between two partners.
 *
 * This contract is easy to deploy: you (Partner A) deploy it and provide
 * Partner B's address. All funds sent to this contract are split 50/50.
 * Each partner can withdraw their share independently at any time.
 */
contract Splitter is ReentrancyGuard {

    // --- State Variables ---
    address public immutable partnerA; // The person who deploys the contract
    address public immutable partnerB; // The second partner
    
    mapping(address => uint256) public shares;

    // --- Events ---
    event FundsReceived(address indexed from, uint256 amount);
    event ShareWithdrawn(address indexed partner, uint256 amount);

    /**
     * @dev Sets up the 50/50 split.
     * @param _partnerB The address of the second partner.
     */
    constructor(address _partnerB) {
        require(_partnerB != address(0), "Partner B cannot be the zero address");
        require(_partnerB != msg.sender, "Partner B cannot be the deployer");
        
        partnerA = msg.sender;
        partnerB = _partnerB;
    }

    /**
     * @dev This is the core logic. This function is called
     * whenever the contract receives ETH.
     * It splits the incoming funds 50/50.
     */
    receive() external payable {
        uint256 amount = msg.value;
        require(amount > 0, "Amount must be greater than 0");

        // Calculate shares (50% to each)
        uint256 shareA = amount / 2;
        uint256 shareB = amount - shareA; // Handles odd wei amounts

        shares[partnerA] += shareA;
        shares[partnerB] += shareB;

        emit FundsReceived(msg.sender, amount);
    }

    /**
     * @dev Allows either partner to withdraw their available share.
     */
    function withdraw() public nonReentrant {
        address partner = msg.sender;
        
        // Only partners can withdraw
        require(partner == partnerA || partner == partnerB, "You are not a partner.");
        
        uint256 amount = shares[partner];
        require(amount > 0, "No funds to withdraw.");

        // Set share to 0 *before* sending to prevent re-entrancy
        shares[partner] = 0;

        // Send the funds
        (bool success, ) = partner.call{value: amount}("");
        require(success, "Withdrawal failed.");

        emit ShareWithdrawn(partner, amount);
    }

    /**
     * @dev View function to check the total balance of the contract.
     */
    function getBalance() public view returns (uint256) {
        return address(this).balance;
    }
}