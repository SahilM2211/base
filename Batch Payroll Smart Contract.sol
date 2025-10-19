// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title BatchPayroll
 * @dev A gas-efficient smart contract for processing payroll for multiple employees in a single transaction.
 * This contract is designed to leverage the low-gas environment of Layer 2 networks like Base.
 * On Ethereum L1, a function like `executePayroll` would be extremely expensive, but on Base,
 * it becomes a practical and cost-effective solution for on-chain payments.
 * The owner of the contract can manage employees, set salaries, and execute the payroll.
 */
contract BatchPayroll {
    address public owner;
    uint256 public totalPayroll;

    struct Employee {
        uint256 salary;
        bool isEmployee;
    }

    mapping(address => Employee) public employees;
    address[] public employeeList;

    event OwnerChanged(address indexed newOwner);
    event EmployeeAdded(address indexed employee, uint256 salary);
    event EmployeeRemoved(address indexed employee);
    event PayrollExecuted(uint256 totalPaid, uint256 timestamp);
    event FundsDeposited(address indexed from, uint256 amount);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only the owner can call this function.");
        _;
    }

    constructor() {
        owner = msg.sender;
        emit OwnerChanged(owner);
    }

    /**
     * @dev Allows the contract to receive Ether to fund the payroll.
     */
    receive() external payable {
        emit FundsDeposited(msg.sender, msg.value);
    }

    /**
     * @dev Adds or updates an employee's salary.
     * @param _employee The address of the employee.
     * @param _salary The monthly salary in wei (1 ether = 1e18 wei).
     */
    function addOrUpdateEmployee(address _employee, uint256 _salary) public onlyOwner {
        require(_employee != address(0), "Invalid employee address.");
        require(_salary > 0, "Salary must be greater than zero.");

        if (!employees[_employee].isEmployee) {
            employees[_employee] = Employee({salary: _salary, isEmployee: true});
            employeeList.push(_employee);
        } else {
            // Adjust total payroll if salary is updated
            totalPayroll = totalPayroll - employees[_employee].salary + _salary;
            employees[_employee].salary = _salary;
        }

        emit EmployeeAdded(_employee, _salary);
    }

     /**
     * @dev Removes an employee from the payroll.
     * Note: This is a simplified removal for demonstration. For very large lists,
     * this operation could be gas-intensive. More advanced data structures could be used.
     * @param _employee The address of the employee to remove.
     */
    function removeEmployee(address _employee) public onlyOwner {
        require(employees[_employee].isEmployee, "Address is not an employee.");

        // Mark as not an employee
        employees[_employee].isEmployee = false;
        totalPayroll -= employees[_employee].salary;

        // In-place removal from the employeeList array
        for (uint i = 0; i < employeeList.length; i++) {
            if (employeeList[i] == _employee) {
                employeeList[i] = employeeList[employeeList.length - 1];
                employeeList.pop();
                break;
            }
        }
        
        emit EmployeeRemoved(_employee);
    }

    /**
     * @dev The core function. Pays all registered employees their salary in a single transaction.
     * This leverages the low gas fees of Base to perform a batch operation.
     */
    function executePayroll() public onlyOwner {
        uint256 requiredFunds = 0;
        for (uint i = 0; i < employeeList.length; i++) {
            address employeeAddress = employeeList[i];
            // Only calculate for active employees
            if(employees[employeeAddress].isEmployee){
                requiredFunds += employees[employeeAddress].salary;
            }
        }
        
        require(address(this).balance >= requiredFunds, "Insufficient funds in contract to execute payroll.");

        for (uint i = 0; i < employeeList.length; i++) {
            address employeeAddress = employeeList[i];
            if(employees[employeeAddress].isEmployee){
                uint256 salary = employees[employeeAddress].salary;
                (bool success, ) = payable(employeeAddress).call{value: salary}("");
                require(success, "Payment to an employee failed.");
            }
        }

        emit PayrollExecuted(requiredFunds, block.timestamp);
    }

    /**
     * @dev Allows the owner to withdraw any remaining funds from the contract.
     */
    function withdrawFunds() public onlyOwner {
        (bool success, ) = payable(owner).call{value: address(this).balance}("");
        require(success, "Withdrawal failed.");
    }
    
    /**
     * @dev Gets the current list of employee addresses.
     * @return An array of addresses.
     */
    function getEmployeeList() public view returns (address[] memory) {
        return employeeList;
    }
}
