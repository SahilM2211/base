// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v5.0.1/contracts/token/ERC721/ERC721.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v5.0.1/contracts/access/Ownable.sol";

/**
 * @title DecentralizedTickets
 * @dev A smart contract for creating and managing event tickets as NFTs.
 * It solves real-world problems of ticket scalping, fraud, and high intermediary fees.
 * Each ticket is a unique ERC721 token, ensuring authenticity and ownership.
 */
contract DecentralizedTickets is ERC721, Ownable {
    uint256 public ticketPrice;
    uint256 public totalTickets;
    uint256 public ticketsSold;
    string public eventName;
    uint256 public eventDate; // Unix timestamp
    bool public salesAreActive;
    mapping(uint256 => bool) public usedTickets;

    event TicketPurchased(address indexed buyer, uint256 indexed tokenId);
    event TicketUsed(uint256 indexed tokenId);
    event SalesStatusChanged(bool active);
    event FundsWithdrawn(address indexed owner, uint256 amount);

    /**
     * @dev Constructor to create a new event.
     * @param _eventName Name of the event.
     * @param _symbol The symbol for the ticket NFT collection (e.g., "EVNT").
     * @param _ticketPrice The price of a single ticket in wei.
     * @param _totalTickets The total number of tickets available for sale.
     * @param _eventDate The date of the event as a Unix timestamp.
     */
    constructor(
        string memory _eventName,
        string memory _symbol,
        uint256 _ticketPrice,
        uint256 _totalTickets,
        uint256 _eventDate
    ) ERC721(_eventName, _symbol) Ownable(msg.sender) {
        require(_ticketPrice > 0, "Ticket price must be greater than zero");
        require(_totalTickets > 0, "Total tickets must be greater than zero");
        require(_eventDate > block.timestamp, "Event date must be in the future");

        eventName = _eventName;
        ticketPrice = _ticketPrice;
        totalTickets = _totalTickets;
        eventDate = _eventDate;
        salesAreActive = true;
    }

    /**
     * @dev Allows a user to purchase a ticket.
     */
    function buyTicket() public payable {
        require(salesAreActive, "Ticket sales are not active");
        require(ticketsSold < totalTickets, "All tickets have been sold");
        require(msg.value == ticketPrice, "Incorrect amount of ETH sent");

        ticketsSold++;
        uint256 tokenId = ticketsSold; // Ticket IDs start from 1
        _safeMint(msg.sender, tokenId);

        emit TicketPurchased(msg.sender, tokenId);
    }

    /**
     * @dev Allows the event owner to verify and "use" a ticket at the venue.
     * This prevents a ticket from being used multiple times.
     * @param _tokenId The ID of the ticket to be used.
     */
    function useTicket(uint256 _tokenId) public onlyOwner {
        // Calling ownerOf(_tokenId) serves as an existence check.
        // It will revert the transaction if the token does not exist.
        ownerOf(_tokenId); 
        require(!usedTickets[_tokenId], "This ticket has already been used");
        
        usedTickets[_tokenId] = true;
        emit TicketUsed(_tokenId);
    }

    /**
     * @dev Toggles the status of ticket sales.
     */
    function toggleSales() public onlyOwner {
        salesAreActive = !salesAreActive;
        emit SalesStatusChanged(salesAreActive);
    }

    /**
     * @dev Allows the owner to withdraw the contract balance after the event.
     */
    function withdraw() public onlyOwner {
        require(block.timestamp > eventDate, "Cannot withdraw funds before the event date");
        uint256 balance = address(this).balance;
        require(balance > 0, "No funds to withdraw");

        (bool success, ) = owner().call{value: balance}("");
        require(success, "Withdrawal failed");

        emit FundsWithdrawn(owner(), balance);
    }

    // --- View Functions ---

    /**
     * @dev Returns the owner of a specific ticket.
     */
    function getTicketOwner(uint256 _tokenId) public view returns (address) {
        return ownerOf(_tokenId);
    }
}

