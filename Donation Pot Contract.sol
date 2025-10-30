// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title DonationPot
 * @dev A simple contract to collect donations.
 * The person who deploys this contract is the owner and is the
 * only one who can withdraw the funds.
 * It's easy to deploy because the constructor takes NO arguments.
 */
contract DonationPot {

    address public immutable owner;
    uint256 public totalDonations;
    mapping(address => uint256) public donations;

    event DonationReceived(address indexed donor, uint256 amount);
    event FundsWithdrawn(address indexed owner, uint256 amount);

    /**
     * @dev Sets the contract deployer as the owner.
     * No arguments are needed to deploy this.
     */
    constructor() {
        owner = msg.sender;
    }

    /**
     * @dev Allows anyone to send ETH to this contract as a donation.
     * The 'payable' keyword is what allows this function to receive ETH.
     */
    function donate() public payable {
        require(msg.value > 0, "Donation must be greater than zero");

        // Update the donor's total contribution
        donations[msg.sender] += msg.value;
        
        // Update the contract's total donations
        totalDonations += msg.value;

        emit DonationReceived(msg.sender, msg.value);
    }

    /**
     * @dev Allows ONLY the owner to withdraw the entire balance.
     */
    function withdraw() public {
        require(msg.sender == owner, "Only the owner can withdraw.");
        uint256 balance = address(this).balance;
        require(balance > 0, "No funds to withdraw.");

        // Send the entire balance to the owner
        (bool success, ) = owner.call{value: balance}("");
        require(success, "Withdrawal failed.");

        emit FundsWithdrawn(owner, balance);
    }

    /**
     * @dev A helper function to see the current balance of the pot.
     */
    function getBalance() public view returns (uint256) {
        return address(this).balance;
    }
}
