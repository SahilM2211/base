// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

/**
 * @title FractionalRealEstate
 * @dev A robust RWA (Real World Asset) contract.
 * It allows tokenizing a property and distributing rent (ETH) to holders.
 *
 * ALGORITHM: "Scalable Reward Distribution"
 * Instead of looping through all holders to pay rent (which costs too much gas),
 * we use a cumulative `accEthPerShare` value.
 *
 * Math:
 * pendingReward = (userBalance * accEthPerShare) - userRewardDebt
 */
contract FractionalRealEstate is ERC20, Ownable, ReentrancyGuard {

    // --- State Variables ---
    uint256 public constant MAGNITUDE = 2**128; // Precision factor for math
    uint256 public accEthPerShare; // Cumulative ETH per 1 token
    
    mapping(address => int256) public rewardDebt; // Tracks what has already been paid to a user
    
    uint256 public totalRentDistributed;
    uint256 public propertyValue; // Valuation in ETH (informational)
    string public propertyAddress; // Physical address (e.g. "123 Ocean Dr")

    // --- Events ---
    event RentDeposited(uint256 amount);
    event RentClaimed(address indexed user, uint256 amount);
    event PropertyInfoUpdated(uint256 newValuation, string newAddress);

    /**
     * @dev Deploy the property token.
     * @param _name e.g. "123 Ocean Drive Shares"
     * @param _symbol e.g. "OCN123"
     * @param _totalSupply Total shares to mint (e.g. 1,000,000)
     */
    constructor(
        string memory _name, 
        string memory _symbol, 
        uint256 _totalSupply,
        string memory _physicalAddress
    ) ERC20(_name, _symbol) Ownable(msg.sender) {
        // Mint all shares to the owner (Issuer) initially
        _mint(msg.sender, _totalSupply * 10**decimals());
        propertyAddress = _physicalAddress;
    }

    /**
     * @dev Property Manager deposits rent (ETH).
     * This updates the global accumulator. Cost is O(1) (Constant Gas).
     */
    function depositRent() public payable {
        require(msg.value > 0, "Rent must be > 0");
        require(totalSupply() > 0, "No shares exist");

        // Calculate how much ETH per share this deposit represents
        // We multiply by MAGNITUDE to prevent precision loss on small amounts
        accEthPerShare += (msg.value * MAGNITUDE) / totalSupply();
        totalRentDistributed += msg.value;

        emit RentDeposited(msg.value);
    }

    /**
     * @dev View function to see how much rent a user can claim right now.
     */
    function getClaimableRent(address _user) public view returns (uint256) {
        int256 accumulated = int256((balanceOf(_user) * accEthPerShare) / MAGNITUDE);
        int256 pending = accumulated - rewardDebt[_user];
        if (pending < 0) return 0;
        return uint256(pending);
    }

    /**
     * @dev User claims their accumulated rent.
     */
    function claimRent() public nonReentrant {
        uint256 pending = getClaimableRent(msg.sender);
        require(pending > 0, "No rent to claim");

        // Update debt so they can't claim this amount again
        rewardDebt[msg.sender] += int256(pending);

        (bool success, ) = msg.sender.call{value: pending}("");
        require(success, "Transfer failed");

        emit RentClaimed(msg.sender, pending);
    }

    /**
     * @dev Override ERC20 transfer. 
     * CRITICAL: We must update rewardDebt when tokens move.
     * If Alice sells to Bob, Alice gets paid her due rent first, 
     * and Bob starts with 0 pending rent.
     */
    function _update(address from, address to, uint256 value) internal override {
        // 1. If 'from' is a real user (not minting), update their debt (reduce it)
        if (from != address(0)) {
            int256 pending = int256((balanceOf(from) * accEthPerShare) / MAGNITUDE) - rewardDebt[from];
            // Ideally we could auto-claim here, but to save gas we just adjust debt
            // Actually, for strict correctness in this simplified model, we adjust debt
            // equivalent to the tokens leaving.
            rewardDebt[from] -= int256((value * accEthPerShare) / MAGNITUDE);
        }

        // 2. If 'to' is a real user (not burning), update their debt (increase it)
        // This ensures they don't get "free rent" from the past
        if (to != address(0)) {
            rewardDebt[to] += int256((value * accEthPerShare) / MAGNITUDE);
        }

        super._update(from, to, value);
    }

    // --- Admin Functions ---
    
    function setPropertyInfo(uint256 _valueInEth, string memory _addr) public onlyOwner {
        propertyValue = _valueInEth;
        propertyAddress = _addr;
        emit PropertyInfoUpdated(_valueInEth, _addr);
    }
    
    // Allow contract to receive ETH
    receive() external payable {
        depositRent();
    }
}