// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "./Employee.sol";

contract Hourly is Employee {
    uint256 public hourlyRate;

    constructor(uint256 _idNumber, uint256 _managerId, uint256 _hourlyRate)
        Employee(_idNumber, _managerId)
    {
        hourlyRate = _hourlyRate;
    }

    function getAnnualCost() public view virtual override returns (uint256) {
        return hourlyRate * 2080;
    }
}