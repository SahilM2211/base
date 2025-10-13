// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

contract Manager {
    uint256[] public reports;

    function addReport(uint256 _idNumber) public {
        reports.push(_idNumber);
    }

    function resetReports() public {
        delete reports;
    }

    function getReports() public view returns (uint256[] memory) {
        return reports;
    }
}