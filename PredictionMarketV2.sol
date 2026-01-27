// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";

contract PredictionMarketV2 is Ownable {

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
    
    // --- 1. THE BANK (Internal Wallet) ---
    mapping(address => uint256) public balances;

    mapping(uint256 => mapping(address => mapping(uint256 => uint256))) public bets;
    mapping(uint256 => mapping(address => bool)) public hasClaimed;

    event MarketCreated(uint256 indexed id, string question, uint256 endTime);
    event BetPlaced(uint256 indexed id, address indexed user, uint256 amount, bool isYes);
    event BalanceUpdated(address indexed user, uint256 newBalance); // To update UI
    event MarketResolved(uint256 indexed id, MarketOutcome outcome);
    event WinningsClaimed(uint256 indexed id, address indexed user, uint256 amount);

    constructor() Ownable(msg.sender) {}

    // --- BANKING FUNCTIONS ---

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

    // --- MARKET FUNCTIONS ---

    function createMarket(string memory _question, uint256 _durationSeconds) public {
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

    // --- 2. DYNAMIC BETTING ---
    // Takes `_amount` (how much to bet from Bank)
    function placeBet(uint256 _marketId, bool _voteYes, uint256 _amount) public payable {
        require(_marketId < markets.length, "Invalid market ID");
        Market storage market = markets[_marketId];
        require(block.timestamp < market.endTime, "Betting has ended");
        require(!market.resolved, "Market already resolved");

        uint256 betAmount;

        // Logic: Prioritize ETH sent directly, otherwise use Bank Balance
        if (msg.value > 0) {
            betAmount = msg.value;
        } else {
            require(_amount > 0, "Bet amount must be > 0");
            require(balances[msg.sender] >= _amount, "Insufficient balance");
            balances[msg.sender] -= _amount;
            betAmount = _amount;
            emit BalanceUpdated(msg.sender, balances[msg.sender]);
        }

        if (_voteYes) {
            market.totalYesAmount += betAmount;
            bets[_marketId][msg.sender][1] += betAmount; 
        } else {
            market.totalNoAmount += betAmount;
            bets[_marketId][msg.sender][0] += betAmount; 
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

    // --- 3. PAYOUT LOGIC ---
    function claimWinnings(uint256 _marketId) public {
        Market storage market = markets[_marketId];
        require(market.resolved, "Market not resolved yet");
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

        // MATH: Your Share = (UserBet / WinningPool) * LosingPool + UserBet
        // This is the exact logic you asked for.
        uint256 reward = (userBet * losingPool) / winningPool;
        uint256 totalPayout = userBet + reward;

        hasClaimed[_marketId][msg.sender] = true;
        balances[msg.sender] += totalPayout; // Winnings go to Bank
        emit BalanceUpdated(msg.sender, balances[msg.sender]);
        emit WinningsClaimed(_marketId, msg.sender, totalPayout);
    }

    function getMarket(uint256 _id) public view returns (string memory, uint256, uint256, uint256, bool, MarketOutcome) {
        Market memory m = markets[_id];
        return (m.question, m.endTime, m.totalYesAmount, m.totalNoAmount, m.resolved, m.outcome);
    }
}