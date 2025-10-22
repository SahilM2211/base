// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title DigitalWill
 * @dev A smart contract that allows an owner to securely transfer their crypto assets
 * to a beneficiary after a period of inactivity. This solves the real-world problem
 * of digital asset inheritance in a decentralized and automated way.
 * The owner sends a "heartbeat" to prove they are active. If the heartbeat is missed
 * for a defined timeout period, the beneficiary can claim the funds.
 */
contract DigitalWill {
    address public owner;
    address public beneficiary;
    uint256 public lastHeartbeat;
    uint256 public immutable heartbeatTimeout; // In seconds

    event BeneficiaryChanged(address indexed newBeneficiary);
    event HeartbeatSent(uint256 timestamp);
    event InheritanceClaimed(address indexed beneficiary, uint256 amount);
    event FundsDeposited(address indexed from, uint256 amount);
    event OwnerWithdrew(uint256 amount);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only the owner can call this function.");
        _;
    }

    /**
     * @param _beneficiary The address of the person to inherit the funds.
     * @param _heartbeatTimeoutInDays The number of days of inactivity before the beneficiary can claim.
     */
    constructor(address _beneficiary, uint256 _heartbeatTimeoutInDays) {
        require(_beneficiary != address(0), "Beneficiary cannot be the zero address.");
        require(_heartbeatTimeoutInDays > 0, "Timeout must be greater than 0 days.");
        
        owner = msg.sender;
        beneficiary = _beneficiary;
        heartbeatTimeout = _heartbeatTimeoutInDays * 1 days;
        lastHeartbeat = block.timestamp;
        
        emit BeneficiaryChanged(_beneficiary);
    }

    /**
     * @dev Allows anyone to deposit Ether into the will. This is payable.
     */
    receive() external payable {
        emit FundsDeposited(msg.sender, msg.value);
    }

    /**
     * @dev The owner calls this function periodically to reset the inactivity timer.
     * This is the "I'm alive" signal.
     */
    function sendHeartbeat() public onlyOwner {
        lastHeartbeat = block.timestamp;
        emit HeartbeatSent(lastHeartbeat);
    }

    /**
     * @dev Allows the owner to change the beneficiary.
     * @param _newBeneficiary The address of the new beneficiary.
     */
    function setBeneficiary(address _newBeneficiary) public onlyOwner {
        require(_newBeneficiary != address(0), "New beneficiary cannot be the zero address.");
        beneficiary = _newBeneficiary;
        emit BeneficiaryChanged(_newBeneficiary);
    }

    /**
     * @dev The beneficiary calls this function to claim the contract's funds.
     * Can only be called after the heartbeat timeout has passed.
     */
    function claimInheritance() public {
        require(msg.sender == beneficiary, "Only the beneficiary can claim.");
        require(block.timestamp > lastHeartbeat + heartbeatTimeout, "Inactivity period has not passed yet.");
        
        uint256 amount = address(this).balance;
        (bool success, ) = payable(beneficiary).call{value: amount}("");
        require(success, "Failed to transfer funds to beneficiary.");
        
        emit InheritanceClaimed(beneficiary, amount);
    }

    /**
     * @dev Allows the owner to withdraw funds while they are still active.
     * @param _amount The amount of wei to withdraw.
     */
    function ownerWithdraw(uint256 _amount) public onlyOwner {
        require(address(this).balance >= _amount, "Insufficient balance.");
        (bool success, ) = payable(owner).call{value: _amount}("");
        require(success, "Withdrawal failed.");
        emit OwnerWithdrew(_amount);
    }

    /**
     * @dev Public view function to check how much time is left before a claim can be made.
     * @return Time remaining in seconds. Returns 0 if the time has passed.
     */
    function getTimeLeft() public view returns (uint256) {
        uint256 claimableTime = lastHeartbeat + heartbeatTimeout;
        if (block.timestamp >= claimableTime) {
            return 0;
        }
        return claimableTime - block.timestamp;
    }
}
