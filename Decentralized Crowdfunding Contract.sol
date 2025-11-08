// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

/**
 * @title CrowdFund
 * @dev Solves the real-world problem of centralized, high-fee crowdfunding.
 * This contract acts as a trustless escrow:
 * 1. If the goal is met, the creator gets the funds.
 * 2. If the goal is not met by the deadline, backers get a refund.
 * This is only viable on a low-fee L2 like Base.
 */
contract CrowdFund is ReentrancyGuard {

    // State enum to track the campaign's progress
    enum State { Funding, Successful, Failed }

    // --- State Variables ---
    address public immutable creator;
    uint256 public immutable fundingGoal; // In wei
    uint256 public immutable deadline; // Unix timestamp
    uint256 public totalRaised;
    State public state;
    mapping(address => uint256) public contributions;

    // --- Events ---
    event Contribution(address indexed backer, uint256 amount);
    event FundsClaimed(address indexed creator, uint256 amount);
    event Refunded(address indexed backer, uint256 amount);
    event CampaignFinished(State finalState);

    /**
     * @dev Sets up the new crowdfunding campaign.
     * @param _fundingGoal The target amount to raise (in wei).
     * @param _durationInDays The number of days the campaign will run.
     */
    constructor(uint256 _fundingGoal, uint256 _durationInDays) {
        require(_fundingGoal > 0, "Funding goal must be > 0");
        require(_durationInDays > 0, "Duration must be > 0");

        creator = msg.sender;
        fundingGoal = _fundingGoal;
        deadline = block.timestamp + (_durationInDays * 1 days);
        state = State.Funding;
    }

    /**
     * @dev Allows anyone to contribute to the campaign.
     */
    function contribute() public payable {
        require(state == State.Funding, "Campaign is not active");
        require(block.timestamp <= deadline, "Campaign has ended");
        require(msg.value > 0, "Contribution must be greater than zero");

        contributions[msg.sender] += msg.value;
        totalRaised += msg.value;

        emit Contribution(msg.sender, msg.value);
    }

    /**
     * @dev Called by anyone after the deadline to finalize the campaign's state.
     */
    function checkFinalState() public {
        require(state == State.Funding, "Campaign already finished");
        require(block.timestamp > deadline, "Campaign is still active");

        if (totalRaised >= fundingGoal) {
            state = State.Successful;
            emit CampaignFinished(State.Successful);
        } else {
            state = State.Failed;
            emit CampaignFinished(State.Failed);
        }
    }

    /**
     * @dev Allows the creator to claim the funds if the campaign was successful.
     */
    function claimFunds() public nonReentrant {
        require(msg.sender == creator, "Only the creator can claim funds");
        require(state == State.Successful, "Campaign was not successful");

        (bool success, ) = creator.call{value: address(this).balance}("");
        require(success, "Transfer failed");

        emit FundsClaimed(creator, address(this).balance);
    }

    /**
     * @dev Allows backers to get a refund if the campaign failed.
     */
    function getRefund() public nonReentrant {
        require(state == State.Failed, "Campaign did not fail");
        
        uint256 amount = contributions[msg.sender];
        require(amount > 0, "You did not contribute or have already been refunded");

        // Set to 0 *before* sending to prevent re-entrancy attacks
        contributions[msg.sender] = 0;

        (bool success, ) = msg.sender.call{value: amount}("");
        require(success, "Refund failed");

        emit Refunded(msg.sender, amount);
    }

    // --- View Functions ---
    function getRemainingTime() public view returns (uint256) {
        if (block.timestamp >= deadline) {
            return 0;
        }
        return deadline - block.timestamp;
    }
}