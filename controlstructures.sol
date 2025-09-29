// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

contract ControlStructures {
    /// @notice Custom error for after-hours access
    error AfterHours(uint time);

    /// @notice Returns "Fizz", "Buzz", "FizzBuzz", or "Splat" based on divisibility
    /// @param _number Number to check
    function fizzBuzz(uint _number) public pure returns (string memory) {
        if (_number % 3 == 0 && _number % 5 == 0) {
            return "FizzBuzz";
        } else if (_number % 3 == 0) {
            return "Fizz";
        } else if (_number % 5 == 0) {
            return "Buzz";
        } else {
            return "Splat";
        }
    }

    /// @notice Responds based on the given time of day
    /// @param _time The time in 24-hour format (e.g., 1330 for 1:30 PM)
    function doNotDisturb(uint _time) public pure returns (string memory) {
        // Panic if time is invalid (>= 2400)
        assert(_time < 2400);

        // Reject after hours
        if (_time > 2200 || _time < 800) {
            revert AfterHours(_time);
        }

        // At lunch
        if (_time >= 1200 && _time <= 1259) {
            revert("At lunch!");
        }

        // Morning
        if (_time >= 800 && _time <= 1199) {
            return "Morning!";
        }

        // Afternoon
        if (_time >= 1300 && _time <= 1799) {
            return "Afternoon!";
        }

        // Evening
        if (_time >= 1800 && _time <= 2200) {
            return "Evening!";
        }

        // Fallback — should never hit this, but return empty just in case
        return "";
    }
}