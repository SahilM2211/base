// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title LostAndFound
 * @dev A decentralized registry for lost items.
 * Owners lock rewards. Finders report items. Owners release rewards.
 *
 * deployment: Easy (No arguments).
 */
contract LostAndFound {

    struct Item {
        address owner;
        uint256 reward;
        address finder;
        bool active;
        bool isFound; // Has a finder reported it?
    }

    // Mapping from Item ID (e.g., "TAG-101") to Item details
    mapping(string => Item) public items;

    event ItemRegistered(string indexed itemId, address indexed owner, uint256 reward);
    event ItemFound(string indexed itemId, address indexed finder);
    event RewardPaid(string indexed itemId, address indexed finder, uint256 amount);
    event ItemCancelled(string indexed itemId);

    constructor() {}

    /**
     * @dev Register a lost item and lock the reward.
     * @param _itemId A unique string on your physical tag (e.g., "KEY-55").
     */
    function registerItem(string memory _itemId) public payable {
        require(msg.value > 0, "Reward must be greater than 0");
        require(items[_itemId].reward == 0, "Item ID already exists");

        items[_itemId] = Item({
            owner: msg.sender,
            reward: msg.value,
            finder: address(0),
            active: true,
            isFound: false
        });

        emit ItemRegistered(_itemId, msg.sender, msg.value);
    }

    /**
     * @dev A Finder calls this to signal they have the item.
     * @param _itemId The ID found on the physical item.
     */
    function reportFound(string memory _itemId) public {
        Item storage item = items[_itemId];
        
        require(item.active, "Item not registered or reward removed");
        require(!item.isFound, "Item already reported found");
        require(msg.sender != item.owner, "Owner cannot find their own item");

        item.finder = msg.sender;
        item.isFound = true;

        emit ItemFound(_itemId, msg.sender);
    }

    /**
     * @dev Owner calls this AFTER getting the item back to pay the finder.
     */
    function confirmAndPay(string memory _itemId) public {
        Item storage item = items[_itemId];

        require(msg.sender == item.owner, "Only owner can release funds");
        require(item.isFound, "No one has reported this found yet");
        require(item.active, "Item inactive");

        uint256 amount = item.reward;
        address finder = item.finder;

        // Update state first
        item.reward = 0;
        item.active = false;

        // Send reward
        (bool success, ) = finder.call{value: amount}("");
        require(success, "Transfer failed");

        emit RewardPaid(_itemId, finder, amount);
    }

    /**
     * @dev Owner can cancel if they find it themselves or want to change the reward.
     */
    function cancelItem(string memory _itemId) public {
        Item storage item = items[_itemId];

        require(msg.sender == item.owner, "Only owner can cancel");
        require(item.active, "Item already inactive");

        uint256 amount = item.reward;
        item.reward = 0;
        item.active = false;
        item.isFound = false;

        (bool success, ) = msg.sender.call{value: amount}("");
        require(success, "Transfer failed");

        emit ItemCancelled(_itemId);
    }

    // --- View Function ---
    function getItemDetails(string memory _itemId) public view returns (
        address owner, 
        uint256 reward, 
        bool isActive, 
        bool isFound, 
        address finder
    ) {
        Item memory item = items[_itemId];
        return (item.owner, item.reward, item.active, item.isFound, item.finder);
    }
}