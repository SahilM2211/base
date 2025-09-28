// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract BasicMath {

    // Adder function
    function adder(uint _a, uint _b) public pure returns (uint sum, bool error) {
        // Check for overflow using the safe addition formula
        unchecked {
            uint result = _a + _b;
            if (result < _a) {
                // Overflow has occurred
                return (0, true);
            }
        }
        // No overflow
        return (_a + _b, false);
    }

    // Subtractor function
    function subtractor(uint _a, uint _b) public pure returns (uint difference, bool error) {
        // Check for underflow using the safe subtraction formula
        if (_b > _a) {
            // Underflow has occurred
            return (0, true);
        }
        // No underflow
        return (_a - _b, false);
    }
}