// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract GarageManager {
    // Define Car struct
    struct Car {
        string make;
        string model;
        string color;
        uint256 numberOfDoors;
    }

    // Mapping: user address => list of Cars
    mapping(address => Car[]) public garage;

    // Custom error for invalid index
    error BadCarIndex(uint256 index);

    /// @notice Add a new car to the sender's garage
    /// @param make The car make
    /// @param model The car model
    /// @param color The car color
    /// @param numberOfDoors The number of doors
    function addCar(
        string memory make,
        string memory model,
        string memory color,
        uint256 numberOfDoors
    ) public {
        Car memory newCar = Car({
            make: make,
            model: model,
            color: color,
            numberOfDoors: numberOfDoors
        });

        garage[msg.sender].push(newCar);
    }

    /// @notice Get all cars owned by the caller
    /// @return cars The array of cars
    function getMyCars() public view returns (Car[] memory cars) {
        return garage[msg.sender];
    }

    /// @notice Get all cars for a given user
    /// @param user The address of the user
    /// @return cars The array of cars
    function getUserCars(address user) public view returns (Car[] memory cars) {
        return garage[user];
    }

    /// @notice Update a car in the caller's garage
    /// @param index The index of the car to update
    /// @param make The new make
    /// @param model The new model
    /// @param color The new color
    /// @param numberOfDoors The new number of doors
    function updateCar(
        uint256 index,
        string memory make,
        string memory model,
        string memory color,
        uint256 numberOfDoors
    ) public {
        if (index >= garage[msg.sender].length) {
            revert BadCarIndex(index);
        }

        garage[msg.sender][index] = Car({
            make: make,
            model: model,
            color: color,
            numberOfDoors: numberOfDoors
        });
    }

    /// @notice Reset the caller's garage (delete all cars)
    function resetMyGarage() public {
        delete garage[msg.sender];
    }
}