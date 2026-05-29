// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import ".deps/npm/@openzeppelin/contracts/security/ReentrancyGuard.sol";

/**
 * @title BaseTrust Protocol
 * @dev Enterprise-grade Generational Wealth Management.
 * Replaces expensive Bank Trustees with immutable cryptographic time-locks.
 * Automatically calculates allowable withdrawals based on cumulative time milestones.
 */
contract BaseTrust is ReentrancyGuard {

    struct Milestone {
        uint256 unlockTime;      // Unix timestamp (e.g., Child's 18th Birthday)
        uint256 cumulativeBPS;   // Basis Points (10000 = 100%). E.g., 2500 means 25% of total wealth is unlocked.
    }

    struct Trust {
        uint256 id;
        address grantor;         // The creator (e.g., Grandparent)
        address beneficiary;     // The receiver (e.g., Child)
        address guardian;        // Emergency override contact (e.g., Parent)
        uint256 totalDeposited;  // Tracks all ETH ever sent to this trust
        uint256 totalClaimed;    // Tracks all ETH the child has withdrawn
        Milestone[] milestones;
    }

    uint256 public trustCounter;
    mapping(uint256 => Trust) public trusts;

    // --- Events ---
    event TrustCreated(uint256 indexed trustId, address indexed grantor, address indexed beneficiary);
    event TrustFunded(uint256 indexed trustId, address indexed funder, uint256 amount);
    event MilestoneClaimed(uint256 indexed trustId, address indexed beneficiary, uint256 amount);
    event GuardianIntervention(uint256 indexed trustId, address indexed guardian, address recipient, uint256 amount, string reason);

    /**
     * @dev 1. Grandparent creates the Trust and defines the Time-Locks.
     */
    function createTrust(
        address _beneficiary,
        address _guardian,
        uint256[] memory _unlockTimes,
        uint256[] memory _cumulativeBPS
    ) public payable {
        require(_beneficiary != address(0), "Invalid beneficiary");
        require(_unlockTimes.length > 0, "Must have at least one milestone");
        require(_unlockTimes.length == _cumulativeBPS.length, "Mismatched milestone arrays");
        
        // Ensure the final milestone does not exceed 100% (10000 BPS)
        for(uint i = 0; i < _cumulativeBPS.length; i++) {
            require(_cumulativeBPS[i] <= 10000, "BPS cannot exceed 10000");
            if (i > 0) {
                require(_cumulativeBPS[i] > _cumulativeBPS[i-1], "Milestones must be strictly increasing in percentage");
                require(_unlockTimes[i] > _unlockTimes[i-1], "Milestones must be strictly chronological");
            }
        }

        uint256 trustId = trustCounter++;
        
        Trust storage t = trusts[trustId];
        t.id = trustId;
        t.grantor = msg.sender;
        t.beneficiary = _beneficiary;
        t.guardian = _guardian;
        t.totalDeposited = msg.value;
        t.totalClaimed = 0;

        for (uint i = 0; i < _unlockTimes.length; i++) {
            t.milestones.push(Milestone({
                unlockTime: _unlockTimes[i],
                cumulativeBPS: _cumulativeBPS[i]
            }));
        }

        emit TrustCreated(trustId, msg.sender, _beneficiary);
        
        if (msg.value > 0) {
            emit TrustFunded(trustId, msg.sender, msg.value);
        }
    }

    /**
     * @dev 2. Anyone (Aunts, Uncles, Parents) can deposit ETH into the child's trust for birthdays/holidays.
     */
    function fundTrust(uint256 _trustId) public payable {
        require(_trustId < trustCounter, "Invalid Trust ID");
        require(msg.value > 0, "Must send ETH");

        Trust storage t = trusts[_trustId];
        t.totalDeposited += msg.value;

        emit TrustFunded(_trustId, msg.sender, msg.value);
    }

    /**
     * @dev Calculate how much ETH the beneficiary is legally allowed to withdraw right now.
     * This math elegantly handles new deposits arriving *after* a milestone has passed.
     */
    function getAvailableToClaim(uint256 _trustId) public view returns (uint256) {
        Trust memory t = trusts[_trustId];
        
        uint256 currentCumulativeBPS = 0;
        
        // Find the highest milestone that has passed
        for (uint i = 0; i < t.milestones.length; i++) {
            if (block.timestamp >= t.milestones[i].unlockTime) {
                currentCumulativeBPS = t.milestones[i].cumulativeBPS;
            }
        }

        if (currentCumulativeBPS == 0) return 0;

        // Total ETH they are entitled to over their lifetime up to this moment
        uint256 totalAllowed = (t.totalDeposited * currentCumulativeBPS) / 10000;
        
        // Subtract what they have already pulled out
        if (totalAllowed <= t.totalClaimed) return 0;
        
        return totalAllowed - t.totalClaimed;
    }

    /**
     * @dev 3. Beneficiary (Child) claims their unlocked funds when they come of age.
     */
    function claim(uint256 _trustId) public nonReentrant {
        Trust storage t = trusts[_trustId];
        require(msg.sender == t.beneficiary, "Only beneficiary can claim");

        uint256 available = getAvailableToClaim(_trustId);
        require(available > 0, "No unlocked funds available to claim");

        t.totalClaimed += available;

        (bool success, ) = t.beneficiary.call{value: available}("");
        require(success, "Transfer failed");

        emit MilestoneClaimed(_trustId, t.beneficiary, available);
    }

    /**
     * @dev 4. Guardian (Parent) can override the time-locks ONLY for emergencies (e.g., Hospital Bills, Tuition).
     * Bypasses the child's wallet and pays the institution directly. Leaves a permanent audit trail.
     */
    function emergencyWithdraw(
        uint256 _trustId, 
        address _recipientInstitution, 
        uint256 _amount, 
        string memory _reason
    ) public nonReentrant {
        Trust storage t = trusts[_trustId];
        require(msg.sender == t.guardian, "Only designated guardian");
        require(_recipientInstitution != address(0), "Invalid recipient");
        
        uint256 currentBalance = t.totalDeposited - t.totalClaimed;
        require(_amount > 0 && _amount <= currentBalance, "Invalid emergency amount");

        // We count emergency withdrawals as "claimed" so it perfectly offsets the child's future math.
        t.totalClaimed += _amount;

        (bool success, ) = _recipientInstitution.call{value: _amount}("");
        require(success, "Emergency transfer failed");

        emit GuardianIntervention(_trustId, msg.sender, _recipientInstitution, _amount, _reason);
    }

    // --- View Helpers ---
    function getMilestones(uint256 _trustId) public view returns (Milestone[] memory) {
        return trusts[_trustId].milestones;
    }
}