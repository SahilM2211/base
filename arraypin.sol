// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract ArraysExercise {
    // Initial array of numbers from 1 to 10
    uint[] public numbers = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10];
    
    // Arrays for saving sender addresses and timestamps
    address[] public senders;
    uint[] public timestamps;

    // Function to return the entire numbers array
    function getNumbers() public view returns (uint[] memory) {
        return numbers;
    }

    // Function to reset the numbers array to its initial values (1-10)
    function resetNumbers() public {
        // Reset the numbers array without using .push() to save gas
        numbers = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10];
    }

    // Function to append a new array to the numbers array
    function appendToNumbers(uint[] calldata _toAppend) public {
        // Append the new array to the numbers array
        for (uint i = 0; i < _toAppend.length; i++) {
            numbers.push(_toAppend[i]);
        }
    }

    // Function to save the timestamp and sender's address
    function saveTimestamp(uint _unixTimestamp) public {
        senders.push(msg.sender);  // Add the sender's address
        timestamps.push(_unixTimestamp);  // Add the timestamp
    }

    // Function to return all timestamps after January 1, 2000
    function afterY2K() public view returns (uint[] memory, address[] memory) {
        uint[] memory recentTimestamps = new uint[](timestamps.length);
        address[] memory recentSenders = new address[](timestamps.length);
        uint count = 0;

        // Loop through timestamps and filter for those after Y2K
        for (uint i = 0; i < timestamps.length; i++) {
            if (timestamps[i] > 946702800) {
                recentTimestamps[count] = timestamps[i];
                recentSenders[count] = senders[i];
                count++;
            }
        }

        // Resize arrays to the actual number of results
        uint[] memory filteredTimestamps = new uint[](count);
        address[] memory filteredSenders = new address[](count);
        for (uint i = 0; i < count; i++) {
            filteredTimestamps[i] = recentTimestamps[i];
            filteredSenders[i] = recentSenders[i];
        }

        return (filteredTimestamps, filteredSenders);
    }

    // Function to reset the senders array
    function resetSenders() public {
        delete senders;
    }

    // Function to reset the timestamps array
    function resetTimestamps() public {
        delete timestamps;
    }
}