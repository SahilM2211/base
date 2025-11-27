// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title SubscriptionManager
 * @dev A simple contract to handle time-based access control.
 * Users pay ETH to buy time. The contract calculates expiration.
 * Perfect for newsletters, premium content, or SaaS access.
 */
contract SubscriptionManager is Ownable {

    uint256 public monthlyRate; // Price in wei for 30 days
    mapping(address => uint256) public expirations; // User Address => Unix Timestamp

    event SubscriptionPurchased(address indexed user, uint256 daysPurchased, uint256 newExpiry);
    event RateUpdated(uint256 newRate);
    event FundsWithdrawn(address indexed owner, uint256 amount);

    /**
     * @dev Easy deployment. Deployer is owner.
     * We set an initial rate (e.g., 0.01 ETH) to avoid "0 price" errors later.
     */
    constructor() Ownable(msg.sender) {
        monthlyRate = 0.01 ether; 
    }

    /**
     * @dev Owner sets the price for a 30-day subscription.
     * @param _rateInWei The price in Wei (e.g. 10000000000000000 for 0.01 ETH)
     */
    function setMonthlyRate(uint256 _rateInWei) public onlyOwner {
        monthlyRate = _rateInWei;
        emit RateUpdated(_rateInWei);
    }

    /**
     * @dev Buy subscription time.
     * The amount sent determines how many days are added based on the monthlyRate.
     */
    function subscribe() public payable {
        require(msg.value > 0, "Must send ETH to subscribe");
        require(monthlyRate > 0, "Subscription rate not set");

        // Calculate seconds purchased: (Payment / MonthlyRate) * 30 days * 24h * 60m * 60s
        // 1 month = 2592000 seconds
        uint256 secondsPurchased = (msg.value * 2592000) / monthlyRate;
        
        require(secondsPurchased > 0, "Payment too small for any time");

        uint256 currentExpiry = expirations[msg.sender];
        uint256 newExpiry;

        // If subscription is already expired or non-existent, start from NOW.
        // If active, add time to the EXISTING expiry.
        if (currentExpiry <= block.timestamp) {
            newExpiry = block.timestamp + secondsPurchased;
        } else {
            newExpiry = currentExpiry + secondsPurchased;
        }

        expirations[msg.sender] = newExpiry;
        emit SubscriptionPurchased(msg.sender, secondsPurchased / 86400, newExpiry);
    }

    /**
     * @dev Check if a specific user has an active subscription.
     */
    function isSubscribed(address _user) public view returns (bool) {
        return expirations[_user] > block.timestamp;
    }

    /**
     * @dev Returns the exact timestamp when the subscription ends.
     */
    function getExpiryDate(address _user) public view returns (uint256) {
        return expirations[_user];
    }

    /**
     * @dev Owner withdraws the earnings.
     */
    function withdraw() public onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No funds to withdraw");
        
        (bool success, ) = owner().call{value: balance}("");
        require(success, "Transfer failed");
        
        emit FundsWithdrawn(owner(), balance);
    }
}