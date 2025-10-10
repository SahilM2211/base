// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "./Salaried.sol";
import "./manager.sol";

contract EngineeringManager is Salaried, Manager {
    constructor(uint256 _idNumber, uint256 _managerId, uint256 _annualSalary)
        Salaried(_idNumber, _managerId, _annualSalary)
    {}
}
