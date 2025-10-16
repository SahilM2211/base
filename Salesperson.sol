// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "./Hourly.sol";

contract Salesperson is Hourly {
    constructor(uint256 _idNumber, uint256 _managerId, uint256 _hourlyRate)
        Hourly(_idNumber, _managerId, _hourlyRate)
    {}
}