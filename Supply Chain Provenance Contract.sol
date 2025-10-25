// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title SupplyChain
 * @dev A smart contract for tracking items through a multi-stage supply chain.
 * It solves the real-world problem of proving provenance and fighting counterfeiting
 * by creating an immutable, transparent history for each item.
 * This contract uses a simple role-based access control for different actors.
 */
contract SupplyChain {
    address public owner; // The administrator of the contract

    // --- Roles ---
    mapping(address => bool) public manufacturers;
    mapping(address => bool) public shippers;
    mapping(address => bool) public retailers;

    // --- Item Structure ---
    enum ItemState { Created, InTransit, ReceivedByRetailer, Sold }

    struct HistoryEntry {
        uint256 timestamp;
        address actor;
        string action;
        ItemState state;
    }

    struct Item {
        uint256 id;
        string info; // e.g., "Organic Coffee Beans - Lot #A542"
        ItemState state;
        address currentOwner;
        HistoryEntry[] history;
    }

    mapping(uint256 => Item) public items;
    uint256 private nextItemId;

    // --- Events ---
    event RoleGranted(address indexed account, string role);
    event RoleRevoked(address indexed account, string role);
    event ItemCreated(uint256 indexed itemId, string info, address indexed manufacturer);
    event ItemStateChanged(uint256 indexed itemId, ItemState newState, address indexed actor);

    // --- Modifiers ---
    modifier onlyOwner() {
        require(msg.sender == owner, "Only the contract owner can call this.");
        _;
    }

    modifier onlyManufacturer() {
        require(manufacturers[msg.sender], "Caller is not a manufacturer.");
        _;
    }

    modifier onlyShipper() {
        require(shippers[msg.sender], "Caller is not a shipper.");
        _;
    }
    
    modifier onlyRetailer() {
        require(retailers[msg.sender], "Caller is not a retailer.");
        _;
    }

    constructor() {
        owner = msg.sender;
        nextItemId = 1;
    }

    // --- Role Management (Owner only) ---
    function grantRole(address _account, uint8 _role) public onlyOwner {
        if (_role == 0) { manufacturers[_account] = true; emit RoleGranted(_account, "Manufacturer"); }
        else if (_role == 1) { shippers[_account] = true; emit RoleGranted(_account, "Shipper"); }
        else if (_role == 2) { retailers[_account] = true; emit RoleGranted(_account, "Retailer"); }
    }

    function revokeRole(address _account, uint8 _role) public onlyOwner {
        if (_role == 0) { manufacturers[_account] = false; emit RoleRevoked(_account, "Manufacturer"); }
        else if (_role == 1) { shippers[_account] = false; emit RoleRevoked(_account, "Shipper"); }
        else if (_role == 2) { retailers[_account] = false; emit RoleRevoked(_account, "Retailer"); }
    }

    // --- Core Functions ---

    /**
     * @dev Manufacturer creates a new item in the system.
     */
    function createItem(string calldata _info) public onlyManufacturer {
        uint256 itemId = nextItemId++;
        items[itemId].id = itemId;
        items[itemId].info = _info;
        items[itemId].state = ItemState.Created;
        items[itemId].currentOwner = msg.sender;
        
        _addHistory(itemId, "Item Created");
        
        emit ItemCreated(itemId, _info, msg.sender);
        emit ItemStateChanged(itemId, ItemState.Created, msg.sender);
    }

    /**
     * @dev The current owner (e.g., Manufacturer) ships the item to a shipper.
     */
    function shipItem(uint256 _itemId, address _shipperAddress) public {
        Item storage item = items[_itemId];
        require(item.id != 0, "Item does not exist.");
        require(item.currentOwner == msg.sender, "You are not the current owner.");
        require(item.state == ItemState.Created, "Item must be in 'Created' state.");
        require(shippers[_shipperAddress], "Receiver must be a registered shipper.");

        item.currentOwner = _shipperAddress;
        item.state = ItemState.InTransit;

        _addHistory(_itemId, "Shipped to Shipper");
        emit ItemStateChanged(_itemId, ItemState.InTransit, msg.sender);
    }

    /**
     * @dev The current owner (Shipper) delivers the item to a retailer.
     */
    function deliverToRetailer(uint256 _itemId, address _retailerAddress) public {
        Item storage item = items[_itemId];
        require(item.id != 0, "Item does not exist.");
        require(item.currentOwner == msg.sender, "You are not the current owner.");
        require(item.state == ItemState.InTransit, "Item must be 'In Transit'.");
        require(retailers[_retailerAddress], "Receiver must be a registered retailer.");

        item.currentOwner = _retailerAddress;
        item.state = ItemState.ReceivedByRetailer;
        
        _addHistory(_itemId, "Delivered to Retailer");
        emit ItemStateChanged(_itemId, ItemState.ReceivedByRetailer, msg.sender);
    }
    
    /**
     * @dev The retailer marks the item as sold to the end consumer.
     */
    function markAsSold(uint256 _itemId) public onlyRetailer {
        Item storage item = items[_itemId];
        require(item.id != 0, "Item does not exist.");
        require(item.currentOwner == msg.sender, "You are not the current owner.");
        require(item.state == ItemState.ReceivedByRetailer, "Item must be with retailer.");

        item.state = ItemState.Sold;
        
        _addHistory(_itemId, "Sold to Consumer");
        emit ItemStateChanged(_itemId, ItemState.Sold, msg.sender);
    }

    // --- View Functions ---

    function getItemHistory(uint256 _itemId) public view returns (HistoryEntry[] memory) {
        return items[_itemId].history;
    }

    // --- Internal Functions ---
    function _addHistory(uint256 _itemId, string memory _action) internal {
        items[_itemId].history.push(HistoryEntry({
            timestamp: block.timestamp,
            actor: msg.sender,
            action: _action,
            state: items[_itemId].state
        }));
    }
}
