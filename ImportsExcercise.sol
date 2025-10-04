// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

// Importing the SillyStringUtils library
import "./SillyStringUtils.sol";

contract ImportsExercise {
    using SillyStringUtils for string;

    // Public Haiku instance stored in contract
    SillyStringUtils.Haiku public haiku;

    /// @notice Save a new haiku
    /// @param _line1 First line
    /// @param _line2 Second line
    /// @param _line3 Third line
    function saveHaiku(string memory _line1, string memory _line2, string memory _line3) public {
        haiku = SillyStringUtils.Haiku({
            line1: _line1,
            line2: _line2,
            line3: _line3
        });
    }

    /// @notice Returns the haiku as a struct (not as individual strings)
    function getHaiku() public view returns (SillyStringUtils.Haiku memory) {
        return haiku;
    }

    /// @notice Returns a haiku with 🤷 appended to line3 (without modifying the original)
    function shruggieHaiku() public view returns (SillyStringUtils.Haiku memory) {
        SillyStringUtils.Haiku memory modified = haiku;
        modified.line3 = modified.line3.shruggie();
        return modified;
    }
}