// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

/**
 * @title BaseGig Escrow
 * @dev A robust freelance escrow system.
 * Solves: Trust issues in remote work without the 20% platform fees.
 * Features:
 * 1. Safe Deposit: Client locks ETH.
 * 2. Handshake: Freelancer must "Accept" to start.
 * 3. Deadlines: Automated refunds if freelancer ghosts.
 * 4. Arbitration: A neutral third party can resolve disputes.
 */
contract GigEscrow is ReentrancyGuard {

    enum State { Created, Active, Submitted, Completed, Disputed, Refunded, Resolved }

    struct Gig {
        uint256 id;
        address client;
        address freelancer;
        address arbiter; // Neutral party for disputes
        string title;
        uint256 amount; // In Wei
        uint256 deadline; // Unix Timestamp
        uint256 lastUpdate;
        State state;
    }

    uint256 public gigCounter;
    mapping(uint256 => Gig) public gigs;

    // Events for frontend tracking
    event GigCreated(uint256 indexed id, address indexed client, address indexed freelancer, uint256 amount);
    event GigAccepted(uint256 indexed id);
    event WorkSubmitted(uint256 indexed id);
    event GigCompleted(uint256 indexed id, uint256 amountReleased);
    event DisputeRaised(uint256 indexed id, address indexed raiser);
    event DisputeResolved(uint256 indexed id, address winner, uint256 amount);
    event Refunded(uint256 indexed id);

    /**
     * @dev Create a new Job. Client sends ETH here.
     * @param _freelancer The wallet address of the worker.
     * @param _arbiter A neutral third party (e.g., a DAO address or mutual friend).
     * @param _title Job description.
     * @param _daysToComplete How many days the freelancer has to finish.
     */
    function createGig(
        address _freelancer, 
        address _arbiter, 
        string memory _title, 
        uint256 _daysToComplete
    ) public payable nonReentrant {
        require(msg.value > 0, "Payment must be > 0");
        require(_freelancer != address(0) && _freelancer != msg.sender, "Invalid freelancer");
        
        gigCounter++;
        
        gigs[gigCounter] = Gig({
            id: gigCounter,
            client: msg.sender,
            freelancer: _freelancer,
            arbiter: _arbiter,
            title: _title,
            amount: msg.value,
            deadline: block.timestamp + (_daysToComplete * 1 days),
            lastUpdate: block.timestamp,
            state: State.Created
        });

        emit GigCreated(gigCounter, msg.sender, _freelancer, msg.value);
    }

    /**
     * @dev Freelancer accepts the job. This locks the contract so Client can't just withdraw immediately.
     */
    function acceptGig(uint256 _id) public {
        Gig storage gig = gigs[_id];
        require(msg.sender == gig.freelancer, "Only freelancer can accept");
        require(gig.state == State.Created, "Gig not available");

        gig.state = State.Active;
        gig.lastUpdate = block.timestamp;
        emit GigAccepted(_id);
    }

    /**
     * @dev Freelancer marks work as done. Stops the deadline timer.
     */
    function submitWork(uint256 _id) public {
        Gig storage gig = gigs[_id];
        require(msg.sender == gig.freelancer, "Only freelancer");
        require(gig.state == State.Active, "Gig not active");

        gig.state = State.Submitted;
        gig.lastUpdate = block.timestamp;
        emit WorkSubmitted(_id);
    }

    /**
     * @dev Happy Path: Client is happy and releases funds to Freelancer.
     */
    function approveAndPay(uint256 _id) public nonReentrant {
        Gig storage gig = gigs[_id];
        require(msg.sender == gig.client, "Only client");
        require(gig.state == State.Submitted || gig.state == State.Active, "Cannot approve now");

        gig.state = State.Completed;
        (bool success, ) = gig.freelancer.call{value: gig.amount}("");
        require(success, "Transfer failed");

        emit GigCompleted(_id, gig.amount);
    }

    /**
     * @dev Sad Path: Either party can raise a dispute if things go wrong.
     * Freezes the funds until Arbiter steps in.
     */
    function raiseDispute(uint256 _id) public {
        Gig storage gig = gigs[_id];
        require(msg.sender == gig.client || msg.sender == gig.freelancer, "Not involved");
        require(gig.state == State.Active || gig.state == State.Submitted, "Cannot dispute now");

        gig.state = State.Disputed;
        emit DisputeRaised(_id, msg.sender);
    }

    /**
     * @dev Arbiter resolves dispute.
     * @param _id The Gig ID.
     * @param _clientShare How much ETH goes back to Client (in Wei).
     * @param _freelancerShare How much ETH goes to Freelancer (in Wei).
     */
    function resolveDispute(uint256 _id, uint256 _clientShare, uint256 _freelancerShare) public nonReentrant {
        Gig storage gig = gigs[_id];
        require(msg.sender == gig.arbiter, "Only arbiter");
        require(gig.state == State.Disputed, "Not disputed");
        require(_clientShare + _freelancerShare <= gig.amount, "Shares exceed total");

        gig.state = State.Resolved;

        if (_clientShare > 0) {
            payable(gig.client).transfer(_clientShare);
        }
        if (_freelancerShare > 0) {
            payable(gig.freelancer).transfer(_freelancerShare);
        }

        emit DisputeResolved(_id, msg.sender, gig.amount);
    }

    /**
     * @dev Safety Valve: If Freelancer ghosts (misses deadline and hasn't submitted),
     * Client can pull funds back without Arbiter.
     */
    function clawback(uint256 _id) public nonReentrant {
        Gig storage gig = gigs[_id];
        require(msg.sender == gig.client, "Only client");
        require(gig.state == State.Active || gig.state == State.Created, "Work already submitted");
        require(block.timestamp > gig.deadline, "Deadline not passed yet");

        gig.state = State.Refunded;
        payable(gig.client).transfer(gig.amount);

        emit Refunded(_id);
    }

    // --- View Functions ---
    function getGigDetails(uint256 _id) public view returns (Gig memory) {
        return gigs[_id];
    }
}