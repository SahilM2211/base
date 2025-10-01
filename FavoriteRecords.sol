// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract FavoriteRecords {
    /// @notice Error for unapproved albums
    error NotApproved(string album);

    // Public mapping of approved album names
    mapping(string => bool) public approvedRecords;

    // Nested mapping: user address => (album name => true/false)
    mapping(address => mapping(string => bool)) private userFavorites;

    // Store album names to iterate for retrieval
    string[] private approvedAlbumList;

    // Track which albums a user has added (to support resetting and listing)
    mapping(address => string[]) private userFavoriteList;

    /// @notice Constructor initializes the approved albums
    constructor() {
        _addApproved("Thriller");
        _addApproved("Back in Black");
        _addApproved("The Bodyguard");
        _addApproved("The Dark Side of the Moon");
        _addApproved("Their Greatest Hits (1971-1975)");
        _addApproved("Hotel California");
        _addApproved("Come On Over");
        _addApproved("Rumours");
        _addApproved("Saturday Night Fever");
    }

    /// @dev Internal function to add approved albums
    function _addApproved(string memory album) internal {
        approvedRecords[album] = true;
        approvedAlbumList.push(album);
    }

    /// @notice Returns the full list of approved album names
    function getApprovedRecords() external view returns (string[] memory) {
        return approvedAlbumList;
    }

    /// @notice Adds a record to the sender's favorites if it's approved
    function addRecord(string memory album) external {
        if (!approvedRecords[album]) {
            revert NotApproved(album);
        }

        // Avoid duplicates
        if (!userFavorites[msg.sender][album]) {
            userFavorites[msg.sender][album] = true;
            userFavoriteList[msg.sender].push(album);
        }
    }

    /// @notice Gets the list of favorite albums for a user
    function getUserFavorites(address user) external view returns (string[] memory) {
        string[] memory favorites = userFavoriteList[user];
        uint256 count = 0;

        // Count how many are still true
        for (uint256 i = 0; i < favorites.length; i++) {
            if (userFavorites[user][favorites[i]]) {
                count++;
            }
        }

        // Create the result array
        string[] memory result = new string[](count);
        uint256 index = 0;

        for (uint256 i = 0; i < favorites.length; i++) {
            string memory album = favorites[i];
            if (userFavorites[user][album]) {
                result[index] = album;
                index++;
            }
        }

        return result;
    }

    /// @notice Resets the sender's favorite list
    function resetUserFavorites() external {
        string[] storage favorites = userFavoriteList[msg.sender];

        for (uint256 i = 0; i < favorites.length; i++) {
            userFavorites[msg.sender][favorites[i]] = false;
        }

        delete userFavoriteList[msg.sender];
    }
}