// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title VerifiableCredentials
 * @dev Solves the real-world problem of slow, expensive, and forgeable
 * academic/professional credentials.
 *
 * It works in three roles:
 * 1. OWNER (The Institution): The university or company that deploys the
 * contract. Only the owner can issue or revoke credentials.
 * 2. RECIPIENT (The Student/Employee): The person who receives the credential.
 * 3. VERIFIER (The Public/Employer): Anyone who wants to check if a
 * credential is authentic.
 *
 * This is perfect for Base, as an institution can issue thousands of
 * credentials for a very low cost.
 */
contract VerifiableCredentials is Ownable {

    struct Credential {
        string credentialName; // e.g., "B.S. in Computer Science"
        address recipient;
        uint256 issueDate;
        bool exists;
    }

    // A unique ID is generated from the recipient's address and the credential name
    // This allows a person to hold multiple credentials.
    mapping(bytes32 => Credential) public credentials;

    event CredentialIssued(
        bytes32 indexed credentialId,
        address indexed recipient,
        string credentialName
    );
    event CredentialRevoked(bytes32 indexed credentialId);

    /**
     * @dev Sets the deployer (the institution) as the owner.
     * This contract is easy to deploy as it takes no arguments.
     */
    constructor() Ownable(msg.sender) {}

    /**
     * @dev OWNER function: Issues a new credential to a recipient.
     * @param _recipient The wallet address of the student/employee.
     * @param _credentialName The name of the degree (e.g., "M.D.", "Data Science Certificate").
     */
    function issueCredential(address _recipient, string memory _credentialName) public onlyOwner {
        require(_recipient != address(0), "Invalid recipient address.");
        require(bytes(_credentialName).length > 0, "Credential name cannot be empty.");
        
        bytes32 credentialId = _getCredentialId(_recipient, _credentialName);
        
        require(!credentials[credentialId].exists, "This credential has already been issued.");

        credentials[credentialId] = Credential(
            _credentialName,
            _recipient,
            block.timestamp,
            true
        );

        emit CredentialIssued(credentialId, _recipient, _credentialName);
    }

    /**
     * @dev OWNER function: Revokes an existing credential.
     * @param _recipient The wallet address of the recipient.
     * @param _credentialName The name of the credential to revoke.
     */
    function revokeCredential(address _recipient, string memory _credentialName) public onlyOwner {
        bytes32 credentialId = _getCredentialId(_recipient, _credentialName);
        require(credentials[credentialId].exists, "Credential does not exist.");

        credentials[credentialId].exists = false;
        emit CredentialRevoked(credentialId);
    }

    /**
     * @dev PUBLIC function: Allows anyone (e.g., an employer) to verify a credential.
     * This is a 'view' function, so it's free to call.
     * @param _recipient The wallet address of the person they are checking.
     * @param _credentialName The name of the credential they are verifying.
     * @return A boolean (true if valid) and the issue date.
     */
    function verifyCredential(
        address _recipient,
        string memory _credentialName
    ) public view returns (bool, uint256) {
        bytes32 credentialId = _getCredentialId(_recipient, _credentialName);
        Credential storage cred = credentials[credentialId];
        
        return (cred.exists, cred.issueDate);
    }

    /**
     * @dev Internal helper function to create a unique ID.
     */
    function _getCredentialId(
        address _recipient,
        string memory _credentialName
    ) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(_recipient, _credentialName));
    }
}
