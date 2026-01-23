// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title LendingCircle
 * @dev A Rotating Savings and Credit Association (ROSCA) on the blockchain.
 * * Members contribute periodically.
 * * One member takes the whole pot each round.
 * * Continues until everyone has been paid.
 *
 * Deployment: Easy (No inputs).
 */
contract LendingCircle {

    enum State { Pending, Active, Completed }

    struct Member {
        address addr;
        bool hasReceivedPot;
        uint256 totalContributed;
    }

    State public state;
    uint256 public contributionAmount; // Amount per person per round
    uint256 public roundDuration;      // Time between rounds
    uint256 public roundStartTime;
    uint256 public currentRound;
    
    address[] public memberAddresses;
    mapping(address => Member) public members;
    
    // The organizer who sets up the rules
    address public organizer;

    event CircleStarted(uint256 contribution, uint256 duration);
    event ContributionMade(address indexed member, uint256 amount);
    event PotDistributed(address indexed receiver, uint256 amount, uint256 round);
    event RoundStarted(uint256 roundNumber, uint256 startTime);

    constructor() {
        organizer = msg.sender;
        state = State.Pending;
    }

    /**
     * @dev Step 1: Organizer initializes the circle rules.
     */
    function setupCircle(uint256 _contributionAmount, uint256 _daysDuration) public {
        require(msg.sender == organizer, "Only organizer");
        require(state == State.Pending, "Circle already started");
        
        contributionAmount = _contributionAmount;
        roundDuration = _daysDuration * 1 days;
    }

    /**
     * @dev Step 2: Friends join the circle.
     */
    function joinCircle() public {
        require(state == State.Pending, "Circle already active");
        require(members[msg.sender].addr == address(0), "Already joined");

        memberAddresses.push(msg.sender);
        members[msg.sender] = Member({
            addr: msg.sender,
            hasReceivedPot: false,
            totalContributed: 0
        });
    }

    /**
     * @dev Step 3: Organizer starts the circle.
     */
    function startCircle() public {
        require(msg.sender == organizer, "Only organizer");
        require(memberAddresses.length > 1, "Need at least 2 members");
        require(contributionAmount > 0, "Setup not complete");

        state = State.Active;
        currentRound = 1;
        roundStartTime = block.timestamp;
        
        emit CircleStarted(contributionAmount, roundDuration);
        emit RoundStarted(1, roundStartTime);
    }

    /**
     * @dev Step 4: Members pay their share for the current round.
     */
    function contribute() public payable {
        require(state == State.Active, "Circle not active");
        require(msg.value == contributionAmount, "Incorrect amount");
        require(members[msg.sender].addr != address(0), "Not a member");

        members[msg.sender].totalContributed += msg.value;
        emit ContributionMade(msg.sender, msg.value);
    }

    /**
     * @dev Step 5: Distribute the pot to the winner of the round.
     * In a strict ROSCA, the order is often fixed or random. 
     * Here, we allow the organizer to trigger it for simplicity, 
     * but check that the receiver hasn't been paid yet.
     */
    function distributePot(address _receiver) public {
        require(msg.sender == organizer, "Only organizer");
        require(state == State.Active, "Circle not active");
        require(!members[_receiver].hasReceivedPot, "Member already received pot");
        
        // Ensure pot is full (everyone paid)
        uint256 potSize = contributionAmount * memberAddresses.length;
        require(address(this).balance >= potSize, "Not everyone has contributed yet");

        members[_receiver].hasReceivedPot = true;
        
        (bool success, ) = _receiver.call{value: potSize}("");
        require(success, "Transfer failed");

        emit PotDistributed(_receiver, potSize, currentRound);

        // Advance round
        if (currentRound == memberAddresses.length) {
            state = State.Completed;
        } else {
            currentRound++;
            roundStartTime = block.timestamp;
            emit RoundStarted(currentRound, roundStartTime);
        }
    }

    // --- View Functions ---
    function getMemberCount() public view returns (uint256) {
        return memberAddresses.length;
    }
}