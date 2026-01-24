// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title SimplePredictionMarket
 * @dev A binary (Yes/No) betting market.
 * Users bet ETH on outcomes. Winners take the losers' money.
 * Zero house fees in this version (100% payout to winners).
 *
 * Deployment: Easy (No inputs).
 */
contract PredictionMarket is Ownable {

    enum MarketOutcome { Pending, No, Yes, Void }

    struct Market {
        uint256 id;
        string question;
        uint256 endTime;
        uint256 totalYesAmount;
        uint256 totalNoAmount;
        MarketOutcome outcome;
        bool resolved;
    }

    Market[] public markets;

    // Mapping: MarketID => User Address => Side (0=No, 1=Yes) => Amount
    mapping(uint256 => mapping(address => mapping(uint256 => uint256))) public bets;
    mapping(uint256 => mapping(address => bool)) public hasClaimed;

    event MarketCreated(uint256 indexed id, string question, uint256 endTime);
    event BetPlaced(uint256 indexed id, address indexed user, uint256 amount, bool isYes);
    event MarketResolved(uint256 indexed id, MarketOutcome outcome);
    event WinningsClaimed(uint256 indexed id, address indexed user, uint256 amount);

    constructor() Ownable(msg.sender) {}

    /**
     * @dev Create a new betting market.
     * @param _question e.g. "Will ETH > 5k by Dec 31?"
     * @param _durationSeconds How long betting is open.
     */
    function createMarket(string memory _question, uint256 _durationSeconds) public onlyOwner {
        markets.push(Market({
            id: markets.length,
            question: _question,
            endTime: block.timestamp + _durationSeconds,
            totalYesAmount: 0,
            totalNoAmount: 0,
            outcome: MarketOutcome.Pending,
            resolved: false
        }));

        emit MarketCreated(markets.length - 1, _question, block.timestamp + _durationSeconds);
    }

    /**
     * @dev Place a bet on a market.
     * @param _marketId The ID of the market.
     * @param _voteYes True for YES, False for NO.
     */
    function placeBet(uint256 _marketId, bool _voteYes) public payable {
        require(_marketId < markets.length, "Invalid market ID");
        Market storage market = markets[_marketId];
        
        require(block.timestamp < market.endTime, "Betting has ended");
        require(!market.resolved, "Market already resolved");
        require(msg.value > 0, "Bet amount must be > 0");

        if (_voteYes) {
            market.totalYesAmount += msg.value;
            bets[_marketId][msg.sender][1] += msg.value; // 1 = Yes
        } else {
            market.totalNoAmount += msg.value;
            bets[_marketId][msg.sender][0] += msg.value; // 0 = No
        }

        emit BetPlaced(_marketId, msg.sender, msg.value, _voteYes);
    }

    /**
     * @dev Admin resolves the market.
     * @param _marketId The market to resolve.
     * @param _didYesWin True if Yes won, False if No won.
     */
    function resolveMarket(uint256 _marketId, bool _didYesWin) public onlyOwner {
        Market storage market = markets[_marketId];
        require(!market.resolved, "Already resolved");
        require(block.timestamp >= market.endTime, "Trading not finished yet");

        market.outcome = _didYesWin ? MarketOutcome.Yes : MarketOutcome.No;
        market.resolved = true;

        emit MarketResolved(_marketId, market.outcome);
    }

    /**
     * @dev Winners call this to withdraw their share.
     */
    function claimWinnings(uint256 _marketId) public {
        Market storage market = markets[_marketId];
        require(market.resolved, "Market not resolved yet");
        require(!hasClaimed[_marketId][msg.sender], "Already claimed");

        uint256 userBetAmount;
        uint256 winningPoolTotal;
        uint256 losingPoolTotal;

        if (market.outcome == MarketOutcome.Yes) {
            userBetAmount = bets[_marketId][msg.sender][1];
            winningPoolTotal = market.totalYesAmount;
            losingPoolTotal = market.totalNoAmount;
        } else if (market.outcome == MarketOutcome.No) {
            userBetAmount = bets[_marketId][msg.sender][0];
            winningPoolTotal = market.totalNoAmount;
            losingPoolTotal = market.totalYesAmount;
        } else {
            revert("Market voided");
        }

        require(userBetAmount > 0, "You did not bet on the winner");
        require(winningPoolTotal > 0, "Winning pool error");

        // Calculate payout: Original Bet + Share of Loser Pool
        // Share = (UserBet / TotalWinningBets) * TotalLosingBets
        uint256 reward = (userBetAmount * losingPoolTotal) / winningPoolTotal;
        uint256 totalPayout = userBetAmount + reward;

        hasClaimed[_marketId][msg.sender] = true;

        (bool success, ) = msg.sender.call{value: totalPayout}("");
        require(success, "Transfer failed");

        emit WinningsClaimed(_marketId, msg.sender, totalPayout);
    }

    // --- View Functions ---
    function getMarketCount() public view returns (uint256) {
        return markets.length;
    }

    function getMarket(uint256 _id) public view returns (
        string memory question, 
        uint256 endTime, 
        uint256 yesPool, 
        uint256 noPool, 
        bool resolved, 
        MarketOutcome outcome
    ) {
        Market memory m = markets[_id];
        return (m.question, m.endTime, m.totalYesAmount, m.totalNoAmount, m.resolved, m.outcome);
    }
}