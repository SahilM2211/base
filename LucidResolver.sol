// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

contract LucidResolver {
    // Returns: (Winner: 1=NO, 2=YES), (FinalPrice), (IsResolved)
    function checkOutcome(
        address _oracleFeed, 
        uint80 _roundId, 
        uint256 _endTime, 
        int256 _targetPrice, 
        bool _isLessThan
    ) external view returns (uint8, int256, bool) {
        
        (, int256 price, , uint256 timeStamp, ) = AggregatorV3Interface(_oracleFeed).getRoundData(_roundId);
        
        // Validation: Round must be within 24 hours of market end
        if (timeStamp < _endTime - 24 hours || timeStamp > _endTime + 24 hours) {
            return (0, 0, false); // Failed validation
        }

        bool conditionMet;
        if (_isLessThan) {
            conditionMet = (price < _targetPrice);
        } else {
            conditionMet = (price >= _targetPrice);
        }

        // Return 2 for YES, 1 for NO
        return (conditionMet ? 2 : 1, price, true);
    }
}