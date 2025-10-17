// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract ActivityStreakVault is Ownable {
    IERC20 public immutable rewardToken;

    struct UserActivity {
        uint256 streak;          // consecutive days interacted
        uint256 lastActiveDay;   // block day (rounded)
        bool claimed;
    }

    mapping(address => UserActivity) public userActivity;
    uint256 public requiredStreak = 5; // e.g. must be active 5 different days
    uint256 public rewardAmount = 100 * 10**18; // amount of reward per eligible user

    event ActivityPing(address indexed user, uint256 streak);
    event RewardClaimed(address indexed user, uint256 amount);

    constructor(address _rewardToken) Ownable(msg.sender) {
        rewardToken = IERC20(_rewardToken);
    }

    function pingActivity() external {
        uint256 today = block.timestamp / 1 days;
        UserActivity storage activity = userActivity[msg.sender];

        require(!activity.claimed, "Already claimed");

        if (activity.lastActiveDay < today) {
            if (activity.lastActiveDay + 1 == today) {
                activity.streak += 1;
            } else {
                activity.streak = 1;
            }
            activity.lastActiveDay = today;
        }

        emit ActivityPing(msg.sender, activity.streak);
    }

    function claimReward() external {
        UserActivity storage activity = userActivity[msg.sender];
        require(!activity.claimed, "Already claimed");
        require(activity.streak >= requiredStreak, "Streak not complete");

        activity.claimed = true;
        rewardToken.transfer(msg.sender, rewardAmount);

        emit RewardClaimed(msg.sender, rewardAmount);
    }

    function setReward(uint256 _amount) external onlyOwner {
        rewardAmount = _amount;
    }

    function setRequiredStreak(uint256 _streak) external onlyOwner {
        requiredStreak = _streak;
    }

    function fundVault(uint256 amount) external {
        rewardToken.transferFrom(msg.sender, address(this), amount);
    }
}
