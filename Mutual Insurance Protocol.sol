// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import ".deps/npm/@openzeppelin/contracts/security/ReentrancyGuard.sol";

/**
 * @title BaseMutual
 * @dev Enterprise-grade Peer-to-Peer Mutual Insurance Pool.
 * Solves the conflict of interest in traditional insurance.
 * Premiums are pooled. Claims are voted on democratically. 
 * Unused funds are refunded to non-claiming members at the end of the term.
 */
contract BaseMutual is ReentrancyGuard {

    struct Member {
        bool isMember;
        bool hasApprovedClaim;
    }

    struct Claim {
        uint256 id;
        address claimant;
        string description;
        uint256 amount;
        uint256 yesVotes;
        uint256 noVotes;
        bool isResolved;
        bool isApproved;
    }

    address public poolManager;
    uint256 public premiumAmount;
    uint256 public maxCoverageAmount;
    uint256 public poolEndTime;
    
    uint256 public totalMembers;
    uint256 public eligibleForRefundCount; // Tracks members who haven't claimed

    mapping(address => Member) public members;
    
    Claim[] public claims;
    // Mapping: ClaimID => MemberAddress => HasVoted
    mapping(uint256 => mapping(address => bool)) public hasVoted;

    // --- Events ---
    event PoolInitialized(uint256 premium, uint256 maxCoverage, uint256 endTime);
    event MemberJoined(address indexed member, uint256 premiumPaid);
    event ClaimSubmitted(uint256 indexed id, address indexed claimant, uint256 amount, string description);
    event Voted(address indexed voter, uint256 indexed claimId, bool support);
    event ClaimResolved(uint256 indexed id, bool approved, uint256 amountPaid);
    event PremiumRefunded(address indexed member, uint256 amount);

    constructor() {
        poolManager = msg.sender;
    }

    /**
     * @dev 1. Initialize the policy parameters.
     */
    function initializePool(
        uint256 _premiumAmount, 
        uint256 _maxCoverageAmount, 
        uint256 _durationDays
    ) public {
        require(msg.sender == poolManager, "Only manager");
        require(poolEndTime == 0, "Pool already initialized");
        require(_premiumAmount > 0 && _maxCoverageAmount >= _premiumAmount, "Invalid amounts");
        
        premiumAmount = _premiumAmount;
        maxCoverageAmount = _maxCoverageAmount;
        poolEndTime = block.timestamp + (_durationDays * 1 days);

        emit PoolInitialized(_premiumAmount, _maxCoverageAmount, poolEndTime);
    }

    /**
     * @dev 2. Users pay the premium to join the risk pool.
     */
    function joinPool() public payable nonReentrant {
        require(poolEndTime > 0, "Pool not initialized");
        require(block.timestamp < poolEndTime, "Pool coverage period has ended");
        require(!members[msg.sender].isMember, "Already a member");
        require(msg.value == premiumAmount, "Must pay exact premium");

        members[msg.sender] = Member({
            isMember: true,
            hasApprovedClaim: false
        });

        totalMembers++;
        eligibleForRefundCount++;

        emit MemberJoined(msg.sender, msg.value);
    }

    /**
     * @dev 3. A member suffers a loss and submits a claim.
     */
    function submitClaim(uint256 _amount, string memory _description) public {
        require(members[msg.sender].isMember, "Not a member");
        require(!members[msg.sender].hasApprovedClaim, "Already received a payout");
        require(block.timestamp < poolEndTime, "Coverage period ended");
        require(_amount > 0 && _amount <= maxCoverageAmount, "Invalid claim amount");

        claims.push(Claim({
            id: claims.length,
            claimant: msg.sender,
            description: _description,
            amount: _amount,
            yesVotes: 0,
            noVotes: 0,
            isResolved: false,
            isApproved: false
        }));

        emit ClaimSubmitted(claims.length - 1, msg.sender, _amount, _description);
    }

    /**
     * @dev 4. Other members act as adjusters and vote on the claim.
     */
    function voteOnClaim(uint256 _claimId, bool _support) public {
        require(members[msg.sender].isMember, "Not a member");
        require(_claimId < claims.length, "Invalid claim ID");
        
        Claim storage claim = claims[_claimId];
        require(!claim.isResolved, "Claim already resolved");
        require(claim.claimant != msg.sender, "Cannot vote on your own claim");
        require(!hasVoted[_claimId][msg.sender], "Already voted");

        hasVoted[_claimId][msg.sender] = true;

        if (_support) {
            claim.yesVotes++;
        } else {
            claim.noVotes++;
        }

        emit Voted(msg.sender, _claimId, _support);
    }

    /**
     * @dev 5. Process the claim after sufficient voting.
     * For security, requires > 50% of ALL eligible members to vote YES for approval.
     */
    function processClaim(uint256 _claimId) public nonReentrant {
        require(_claimId < claims.length, "Invalid claim ID");
        Claim storage claim = claims[_claimId];
        require(!claim.isResolved, "Claim already resolved");

        claim.isResolved = true;

        // Mathematical majority: yesVotes must be strictly greater than half of total members
        if (claim.yesVotes > (totalMembers / 2)) {
            require(address(this).balance >= claim.amount, "Insufficient pool funds");
            
            claim.isApproved = true;
            members[claim.claimant].hasApprovedClaim = true;
            eligibleForRefundCount--; // This member no longer gets a refund at the end

            (bool success, ) = claim.claimant.call{value: claim.amount}("");
            require(success, "Payout transfer failed");
            
            emit ClaimResolved(_claimId, true, claim.amount);
        } else {
            claim.isApproved = false;
            emit ClaimResolved(_claimId, false, 0);
        }
    }

    /**
     * @dev 6. The Magic: At the end of the year, unused funds are returned to members who didn't claim.
     */
    function claimNoClaimBonus() public nonReentrant {
        require(block.timestamp >= poolEndTime, "Coverage period has not ended yet");
        require(members[msg.sender].isMember, "Not a member");
        require(!members[msg.sender].hasApprovedClaim, "You claimed funds, no refund eligible");
        
        // Calculate the exact mathematical share of the remaining pool
        uint256 remainingPool = address(this).balance;
        require(remainingPool > 0, "Pool is empty");
        require(eligibleForRefundCount > 0, "Math error");

        uint256 refundAmount = remainingPool / eligibleForRefundCount;
        
        // Remove membership to prevent double claiming
        members[msg.sender].isMember = false;
        eligibleForRefundCount--;

        (bool success, ) = msg.sender.call{value: refundAmount}("");
        require(success, "Refund transfer failed");

        emit PremiumRefunded(msg.sender, refundAmount);
    }

    // --- View Helpers ---
    function getClaimsCount() public view returns (uint256) {
        return claims.length;
    }

    function getClaim(uint256 _id) public view returns (Claim memory) {
        return claims[_id];
    }
}