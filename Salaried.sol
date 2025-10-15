// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "./Employee.sol";

contract Salaried is Employee {
    uint256 public annualSalary;

    constructor(uint256 _idNumber, uint256 _managerId, uint256 _annualSalary)
        Employee(_idNumber, _managerId)
    {
        annualSalary = _annualSalary;
    }

    function getAnnualCost() public view virtual override returns (uint256) {
        return annualSalary;
    }
}