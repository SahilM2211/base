// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

/**
 * @title BaseLeaseEscrow
 * @dev Enterprise-grade smart contract for rental security deposits and rent tracking.
 * * Features:
 * - Immutable Rent Receipts.
 * - Two-party consent required for deposit deductions.
 * - Third-party arbitration fallback for disputes.
 * - Reentrancy protection for all financial transfers.
 */
contract BaseLeaseEscrow is ReentrancyGuard {

    enum LeaseState { Created, Funded, EndProposed, Disputed, Resolved, Completed }

    struct Lease {
        uint256 id;
        address landlord;
        address tenant;
        address arbiter;
        uint256 depositAmount;
        uint256 rentAmount;
        
        // End of lease proposal
        uint256 proposedTenantShare;
        uint256 proposedLandlordShare;
        
        LeaseState state;
    }

    uint256 public leaseCounter;
    mapping(uint256 => Lease) public leases;

    // Events for frontend tracking
    event LeaseCreated(uint256 indexed id, address indexed landlord, address indexed tenant, uint256 deposit);
    event LeaseFunded(uint256 indexed id);
    event RentPaid(uint256 indexed id, uint256 amount, uint256 timestamp);
    event RefundProposed(uint256 indexed id, uint256 tenantShare, uint256 landlordShare);
    event RefundAgreed(uint256 indexed id);
    event DisputeRaised(uint256 indexed id);
    event DisputeResolved(uint256 indexed id, uint256 tenantShare, uint256 landlordShare);

    /**
     * @dev Landlord creates the lease terms.
     */
    function createLease(
        address _tenant,
        address _arbiter,
        uint256 _depositAmount,
        uint256 _rentAmount
    ) public {
        require(_tenant != address(0) && _arbiter != address(0), "Invalid addresses");
        require(_tenant != msg.sender && _arbiter != msg.sender, "Roles must be distinct");
        require(_depositAmount > 0, "Deposit must be > 0");

        leaseCounter++;
        leases[leaseCounter] = Lease({
            id: leaseCounter,
            landlord: msg.sender,
            tenant: _tenant,
            arbiter: _arbiter,
            depositAmount: _depositAmount,
            rentAmount: _rentAmount,
            proposedTenantShare: 0,
            proposedLandlordShare: 0,
            state: LeaseState.Created
        });

        emit LeaseCreated(leaseCounter, msg.sender, _tenant, _depositAmount);
    }

    /**
     * @dev Tenant reviews the terms and funds the security deposit to lock the contract.
     */
    function fundDeposit(uint256 _id) public payable nonReentrant {
        Lease storage l = leases[_id];
        require(msg.sender == l.tenant, "Only tenant can fund");
        require(l.state == LeaseState.Created, "Invalid state");
        require(msg.value == l.depositAmount, "Must send exact deposit amount");

        l.state = LeaseState.Funded;
        emit LeaseFunded(_id);
    }

    /**
     * @dev Tenant pays monthly rent. Funds are routed instantly to Landlord.
     * This creates an immutable blockchain receipt of rent payment.
     */
    function payRent(uint256 _id) public payable nonReentrant {
        Lease storage l = leases[_id];
        require(msg.sender == l.tenant, "Only tenant");
        require(l.state == LeaseState.Funded, "Lease not active");
        require(msg.value == l.rentAmount, "Must send exact rent amount");

        // Instantly forward rent to landlord
        (bool success, ) = l.landlord.call{value: msg.value}("");
        require(success, "Rent transfer failed");

        emit RentPaid(_id, msg.value, block.timestamp);
    }

    /**
     * @dev Lease ends. Landlord proposes how the deposit should be split.
     * e.g., Full refund, or a deduction for damages.
     */
    function proposeDeduction(uint256 _id, uint256 _tenantShare, uint256 _landlordShare) public {
        Lease storage l = leases[_id];
        require(msg.sender == l.landlord, "Only landlord");
        require(l.state == LeaseState.Funded, "Invalid state");
        require(_tenantShare + _landlordShare == l.depositAmount, "Shares must equal total deposit");

        l.proposedTenantShare = _tenantShare;
        l.proposedLandlordShare = _landlordShare;
        l.state = LeaseState.EndProposed;

        emit RefundProposed(_id, _tenantShare, _landlordShare);
    }

    /**
     * @dev Tenant agrees to the proposed split. Funds are distributed safely.
     */
    function tenantAgree(uint256 _id) public nonReentrant {
        Lease storage l = leases[_id];
        require(msg.sender == l.tenant, "Only tenant");
        require(l.state == LeaseState.EndProposed, "No proposal exists");

        l.state = LeaseState.Completed;
        _distributeFunds(l.landlord, l.tenant, l.proposedLandlordShare, l.proposedTenantShare);
        
        emit RefundAgreed(_id);
    }

    /**
     * @dev Tenant disagrees with deductions. Freezes the contract for Arbitration.
     */
    function raiseDispute(uint256 _id) public {
        Lease storage l = leases[_id];
        require(msg.sender == l.tenant || msg.sender == l.landlord, "Not authorized");
        require(l.state == LeaseState.EndProposed || l.state == LeaseState.Funded, "Cannot dispute now");

        l.state = LeaseState.Disputed;
        emit DisputeRaised(_id);
    }

    /**
     * @dev Neutral Arbiter resolves the dispute with final binding split.
     */
    function resolveDispute(uint256 _id, uint256 _tenantShare, uint256 _landlordShare) public nonReentrant {
        Lease storage l = leases[_id];
        require(msg.sender == l.arbiter, "Only arbiter");
        require(l.state == LeaseState.Disputed, "Not in dispute");
        require(_tenantShare + _landlordShare == l.depositAmount, "Shares must equal total deposit");

        l.state = LeaseState.Resolved;
        _distributeFunds(l.landlord, l.tenant, _landlordShare, _tenantShare);

        emit DisputeResolved(_id, _tenantShare, _landlordShare);
    }

    /**
     * @dev Internal helper to process payouts securely.
     */
    function _distributeFunds(address _landlord, address _tenant, uint256 _lShare, uint256 _tShare) internal {
        if (_lShare > 0) {
            (bool successL, ) = _landlord.call{value: _lShare}("");
            require(successL, "Landlord transfer failed");
        }
        if (_tShare > 0) {
            (bool successT, ) = _tenant.call{value: _tShare}("");
            require(successT, "Tenant transfer failed");
        }
    }

    // --- View Functions ---
    function getLease(uint256 _id) public view returns (Lease memory) {
        return leases[_id];
    }
}