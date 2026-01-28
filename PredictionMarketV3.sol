// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";

contract PredictionMarketV3 is Ownable {
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
    mapping(address => uint256) public balances;
    mapping(uint256 => mapping(address => mapping(uint256 => uint256))) public bets;
    mapping(uint256 => mapping(address => bool)) public hasClaimed;

    // --- 🆕 NEW: HISTORY TRACKING ---
    // Keeps a list of IDs for every market a user has bet on
    mapping(address => uint256[]) public userBets;
    // Helper to prevent adding the same ID twice
    mapping(uint256 => mapping(address => bool)) public hasBetOnMarket;

    event MarketCreated(uint256 indexed id, string question, uint256 endTime);
    event BetPlaced(uint256 indexed id, address indexed user, uint256 amount, bool isYes);
    event BalanceUpdated(address indexed user, uint256 newBalance);
    event MarketResolved(uint256 indexed id, MarketOutcome outcome);
    event WinningsClaimed(uint256 indexed id, address indexed user, uint256 amount);

    constructor() Ownable(msg.sender) {}

    // --- BANKING ---
    function deposit() public payable {
        require(msg.value > 0, "Deposit must be > 0");
        balances[msg.sender] += msg.value;
        emit BalanceUpdated(msg.sender, balances[msg.sender]);
    }

    function withdraw(uint256 _amount) public {
        require(balances[msg.sender] >= _amount, "Insufficient balance");
        balances[msg.sender] -= _amount;
        (bool success, ) = payable(msg.sender).call{value: _amount}("");
        require(success, "Transfer failed");
        emit BalanceUpdated(msg.sender, balances[msg.sender]);
    }

    // --- ADMIN ONLY CREATION ---
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

    // --- BETTING (With History Update) ---
    function placeBet(uint256 _marketId, bool _voteYes, uint256 _amount) public payable {
        require(_marketId < markets.length, "Invalid market ID");
        Market storage market = markets[_marketId];
        require(block.timestamp < market.endTime, "Betting has ended");
        require(!market.resolved, "Market already resolved");

        uint256 betAmount;
        if (msg.value > 0) {
            betAmount = msg.value;
        } else {
            require(_amount > 0, "Bet amount must be > 0");
            require(balances[msg.sender] >= _amount, "Insufficient balance");
            balances[msg.sender] -= _amount;
            betAmount = _amount;
            emit BalanceUpdated(msg.sender, balances[msg.sender]);
        }

        // Record the bet
        if (_voteYes) {
            market.totalYesAmount += betAmount;
            bets[_marketId][msg.sender][1] += betAmount; 
        } else {
            market.totalNoAmount += betAmount;
            bets[_marketId][msg.sender][0] += betAmount; 
        }

        // 🆕 NEW: Add to User History if it's their first bet on this market
        if (!hasBetOnMarket[_marketId][msg.sender]) {
            userBets[msg.sender].push(_marketId);
            hasBetOnMarket[_marketId][msg.sender] = true;
        }

        emit BetPlaced(_marketId, msg.sender, betAmount, _voteYes);
    }

    function resolveMarket(uint256 _marketId, bool _didYesWin) public onlyOwner {
        Market storage market = markets[_marketId];
        require(!market.resolved, "Already resolved");
        market.outcome = _didYesWin ? MarketOutcome.Yes : MarketOutcome.No;
        market.resolved = true;
        emit MarketResolved(_marketId, market.outcome);
    }

    function claimWinnings(uint256 _marketId) public {
        Market storage market = markets[_marketId];
        require(market.resolved, "Market not resolved");
        require(!hasClaimed[_marketId][msg.sender], "Already claimed");

        uint256 userBet;
        uint256 winningPool;
        uint256 losingPool;

        if (market.outcome == MarketOutcome.Yes) {
            userBet = bets[_marketId][msg.sender][1];
            winningPool = market.totalYesAmount;
            losingPool = market.totalNoAmount;
        } else if (market.outcome == MarketOutcome.No) {
            userBet = bets[_marketId][msg.sender][0];
            winningPool = market.totalNoAmount;
            losingPool = market.totalYesAmount;
        } else {
            revert("Void");
        }

        require(userBet > 0, "No winnings");
        uint256 reward = (userBet * losingPool) / winningPool;
        uint256 totalPayout = userBet + reward;

        hasClaimed[_marketId][msg.sender] = true;
        balances[msg.sender] += totalPayout; 
        emit BalanceUpdated(msg.sender, balances[msg.sender]);
        emit WinningsClaimed(_marketId, msg.sender, totalPayout);
    }

    // --- READ FUNCTIONS ---

    function getMarketCount() public view returns (uint256) {
        return markets.length;
    }

    function getMarket(uint256 _id) public view returns (string memory, uint256, uint256, uint256, bool, MarketOutcome) {
        Market memory m = markets[_id];
        return (m.question, m.endTime, m.totalYesAmount, m.totalNoAmount, m.resolved, m.outcome);
    }

    // 🆕 NEW: Get all market IDs a user has participated in
    function getUserBets(address _user) public view returns (uint256[] memory) {
        return userBets[_user];
    }
}