// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title CryptoAllowance
 * @dev A smart contract that "drips" funds to a beneficiary over time.
 * Perfect for:
 * 1. Children's allowance.
 * 2. Trust funds.
 * 3. Employee weekly payroll.
 *
 * The beneficiary can only withdraw the set amount once per time period.
 */
contract CryptoAllowance is Ownable {

    address public beneficiary;
    uint256 public payoutAmount; // How much they get (in wei)
    uint256 public payoutFrequency; // How often (in seconds)
    uint256 public lastPayoutTime; // When they last withdrew

    event AllowancePaid(address indexed beneficiary, uint256 amount);
    event FundsDeposited(address indexed depositor, uint256 amount);
    event SettingsUpdated(uint256 newAmount, uint256 newFrequency);

    /**
     * @dev Deploy the contract with the initial settings.
     * @param _beneficiary Who gets the money.
     * @param _payoutAmount How much they get per period (in Wei).
     * @param _daysFrequency How many days between payments.
     */
    constructor(
        address _beneficiary, 
        uint256 _payoutAmount, 
        uint256 _daysFrequency
    ) Ownable(msg.sender) {
        require(_beneficiary != address(0), "Invalid address");
        require(_payoutAmount > 0, "Amount must be > 0");
        require(_daysFrequency > 0, "Frequency must be > 0");

        beneficiary = _beneficiary;
        payoutAmount = _payoutAmount;
        payoutFrequency = _daysFrequency * 1 days;
        
        // Allow immediate withdrawal upon deployment? 
        // Let's set lastPayout to the past so they can claim immediately.
        lastPayoutTime = block.timestamp - payoutFrequency;
    }

    /**
     * @dev Receive funds to top up the allowance bank.
     */
    receive() external payable {
        emit FundsDeposited(msg.sender, msg.value);
    }

    /**
     * @dev The Beneficiary calls this to claim their allowance.
     */
    function collectAllowance() public {
        require(msg.sender == beneficiary, "Only the beneficiary can collect.");
        require(block.timestamp >= lastPayoutTime + payoutFrequency, "Allowance not yet available. Wait longer.");
        require(address(this).balance >= payoutAmount, "Not enough funds in the bank. Ask the owner to top up.");

        lastPayoutTime = block.timestamp;
        
        (bool success, ) = beneficiary.call{value: payoutAmount}("");
        require(success, "Transfer failed.");

        emit AllowancePaid(beneficiary, payoutAmount);
    }

    /**
     * @dev Owner can update the rules (raise/lower allowance).
     */
    function updateSettings(uint256 _newAmount, uint256 _newDays) public onlyOwner {
        payoutAmount = _newAmount;
        payoutFrequency = _newDays * 1 days;
        emit SettingsUpdated(_newAmount, payoutFrequency);
    }

    /**
     * @dev Owner can withdraw all funds (emergency drain).
     */
    function withdrawFunds() public onlyOwner {
        (bool success, ) = owner().call{value: address(this).balance}("");
        require(success, "Transfer failed.");
    }

    // --- View Functions ---

    /**
     * @dev Check how much time until the next payout is unlocked.
     */
    function timeUntilNextPayout() public view returns (uint256) {
        if (block.timestamp >= lastPayoutTime + payoutFrequency) {
            return 0; // Available now
        }
        return (lastPayoutTime + payoutFrequency) - block.timestamp;
    }
}