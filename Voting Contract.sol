// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title DecentralizedVoting
 * @dev A simple, transparent voting system.
 * The deployer is the "Chairperson" who adds proposals.
 * Users can vote for their favorite proposal.
 * Double-voting is prevented.
 */
contract DecentralizedVoting {

    struct Proposal {
        string name;   // Description of the option (e.g., "Alice", "Bob")
        uint256 voteCount; // Number of accumulated votes
    }

    address public chairperson;
    string public electionTitle;
    
    // Array of all proposals
    Proposal[] public proposals;

    // Mapping to check if a user has already voted
    mapping(address => bool) public hasVoted;

    // Events
    event ProposalAdded(string name);
    event Voted(address indexed voter, uint256 proposalIndex);

    /**
     * @dev Constructor.
     * Easy deployment: Just give the election a name!
     * @param _electionTitle The name of the vote (e.g., "Club President")
     */
    constructor(string memory _electionTitle) {
        chairperson = msg.sender;
        electionTitle = _electionTitle;
    }

    /**
     * @dev Chairperson adds a new option to vote for.
     */
    function addProposal(string memory _name) public {
        require(msg.sender == chairperson, "Only chairperson can add proposals.");
        proposals.push(Proposal({
            name: _name,
            voteCount: 0
        }));
        emit ProposalAdded(_name);
    }

    /**
     * @dev Cast your vote for a specific proposal index.
     */
    function vote(uint256 _proposalIndex) public {
        require(!hasVoted[msg.sender], "You have already voted.");
        require(_proposalIndex < proposals.length, "Invalid proposal index.");

        hasVoted[msg.sender] = true;
        proposals[_proposalIndex].voteCount += 1;

        emit Voted(msg.sender, _proposalIndex);
    }

    /**
     * @dev Returns the entire list of proposals (helper for frontend).
     */
    function getAllProposals() public view returns (Proposal[] memory) {
        return proposals;
    }

    /**
     * @dev Returns the current winning proposal name.
     */
    function getWinnerName() public view returns (string memory winnerName) {
        uint256 winningVoteCount = 0;
        uint256 winningProposalIndex = 0;
        
        // Find the proposal with the highest votes
        for (uint p = 0; p < proposals.length; p++) {
            if (proposals[p].voteCount > winningVoteCount) {
                winningVoteCount = proposals[p].voteCount;
                winningProposalIndex = p;
            }
        }

        if (proposals.length > 0) {
            winnerName = proposals[winningProposalIndex].name;
        } else {
            winnerName = "No proposals yet";
        }
    }
}