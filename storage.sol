// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// Custom error for exceeding the share limit.
error TooManyShares(uint256 newShares);

/**
 * @title EmployeeStorage
 * @dev A contract to store employee information, demonstrating state variable storage packing.
 */
contract EmployeeStorage {

    // State variables are arranged to optimize storage packing.
    // 'shares' (uint16) and 'salary' (uint32) are packed into a single 32-byte storage slot.
    // This saves gas on deployment and state changes.
    uint16 internal shares;
    uint32 internal salary;

    // These variables each occupy their own 32-byte storage slot.
   string public name;
uint256 public idNumber;

    /**
     * @dev The constructor initializes the contract with the required employee data.
     * @param _shares The number of shares the employee has.
     * @param _name The employee's name.
     * @param _salary The employee's salary.
     * @param _idNumber The employee's ID number.
     */
    constructor(
        uint16 _shares,
        string memory _name,
        uint32 _salary,
        uint256 _idNumber
    ) {
        // Set the state variables to the provided values.
        // For this specific test, these will be:
        // shares: 1000
        // name: "Pat"
        // salary: 50000
        // idNumber: 112358132134
        shares = _shares;
        name = _name;
        salary = _salary;
        idNumber = _idNumber;
    }

    /**
     * @dev Returns the employee's salary.
     * @return The employee's salary as a uint32.
     */
    function viewSalary() public view returns (uint32) {
        return salary;
    }

    /**
     * @dev Returns the employee's number of shares.
     * @return The number of shares as a uint16.
     */
    function viewShares() public view returns (uint16) {
        return shares;
    }

    /**
     * @dev Grants a specified number of new shares to the employee.
     * @param _newShares The number of shares to grant.
     */
    function grantShares(uint16 _newShares) public {
        // Revert if the new shares amount is greater than 5000, as per the rules.
        if (_newShares > 5000) {
            revert("Too many shares");
        }

        // Calculate the total shares after adding the new amount.
        uint16 newTotalShares = shares + _newShares;

        // Revert with a custom error if the total shares exceed 5000.
        // This indicates the employee would become a director.
        if (newTotalShares > 5000) {
            revert TooManyShares(newTotalShares);
        }

        // Add the new shares to the employee's total.
        shares = newTotalShares;
    }


    /*** Do not modify this function.  It is used to enable the unit test for this pin
     * to check whether or not you have configured your storage variables to make
     * use of packing.
     *
     * If you wish to cheat, simply modify this function to always return `0`
     * I'm not your boss ¯\_(ツ)_/¯
     *
     * Fair warning though, if you do cheat, it will be on the blockchain having been
     * deployed by your wallet....FOREVER!
     */
    function checkForPacking(uint _slot) public view returns (uint r) {
        assembly {
            r := sload (_slot)
        }
    }

    /*** Warning: Anyone can use this function at any time!*/
    function debugResetShares() public {
        shares = 1000;
    }
}