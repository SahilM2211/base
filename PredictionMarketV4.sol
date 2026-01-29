// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

contract PredictionMarketV7 is Ownable {
    enum MarketOutcome { Pending, No, Yes, Void }

    struct Market {
        uint256 id;
        string question;
        uint256 endTime;
        uint256 totalYesAmount;
        uint256 totalNoAmount;
        MarketOutcome outcome;
        bool resolved;
        // 👇 NEW: Oracle Config
        int256 targetPrice;
        address oracleFeed;
        bool isOracleMarket;
    }

    Market[] public markets;
    mapping(address => uint256) public balances;
    
    // V3 Style Mapping: marketId => user => outcome (0 or 1) => amount
    mapping(uint256 => mapping(address => mapping(uint256 => uint256))) public bets;
    mapping(uint256 => mapping(address => bool)) public hasClaimed;

    // --- HISTORY TRACKING (V3 Feature) ---
    mapping(address => uint256[]) public userBets;
    mapping(uint256 => mapping(address => bool)) public hasBetOnMarket;

    // --- SAFETY LOGIC (3-Day Rule) ---
    uint256 public constant SAFETY_PERIOD = 3 days;

    event MarketCreated(uint256 indexed id, string question, uint256 endTime, address oracleFeed);
    event BetPlaced(uint256 indexed id, address indexed user, uint256 amount, bool isYes);
    event BalanceUpdated(address indexed user, uint256 newBalance);
    event MarketResolved(uint256 indexed id, MarketOutcome outcome, int256 finalPrice);
    event WinningsClaimed(uint256 indexed id, address indexed user, uint256 amount);

    constructor() Ownable(msg.sender) {}

    // --- BANKING (V3 Exact Logic) ---
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

    // --- MARKET CREATION (Updated for Oracle) ---
    function createMarket(
        string memory _question, 
        uint256 _durationSeconds,
        int256 _targetPrice,    // 👈 NEW
        address _oracleFeed     // 👈 NEW
    ) public onlyOwner {
        bool isAuto = _oracleFeed != address(0);

        markets.push(Market({
            id: markets.length,
            question: _question,
            endTime: block.timestamp + _durationSeconds,
            totalYesAmount: 0,
            totalNoAmount: 0,
            outcome: MarketOutcome.Pending,
            resolved: false,
            targetPrice: _targetPrice,
            oracleFeed: _oracleFeed,
            isOracleMarket: isAuto
        }));

        emit MarketCreated(markets.length - 1, _question, block.timestamp + _durationSeconds, _oracleFeed);
    }

    // --- BETTING (V3 Exact Logic) ---
    // Handles both direct ETH bets and Balance bets in one function
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

        // Record the bet (V3 Mapping Style)
        if (_voteYes) {
            market.totalYesAmount += betAmount;
            bets[_marketId][msg.sender][1] += betAmount; 
        } else {
            market.totalNoAmount += betAmount;
            bets[_marketId][msg.sender][0] += betAmount; 
        }

        // History Tracking
        if (!hasBetOnMarket[_marketId][msg.sender]) {
            userBets[msg.sender].push(_marketId);
            hasBetOnMarket[_marketId][msg.sender] = true;
        }

        emit BetPlaced(_marketId, msg.sender, betAmount, _voteYes);
    }

    // --- RESOLUTION (The New "3-Day" + Oracle Logic) ---
    function resolveMarket(uint256 _marketId, bool _manualYesWin) public {
        Market storage market = markets[_marketId];
        require(!market.resolved, "Already resolved");
        require(block.timestamp >= market.endTime, "Not ended yet");

        // 🕒 CHECK PRIORITY PERIOD (3 Days)
        // If < 3 days passed: Only Admin can touch this.
        // If > 3 days passed: Anyone can touch this (Priority Expired).
        bool isPriorityPeriod = block.timestamp < (market.endTime + SAFETY_PERIOD);

        if (market.isOracleMarket) {
            // --- 🤖 ORACLE PATH ---
            if (isPriorityPeriod) {
                require(msg.sender == owner(), "Only Owner (Priority Period)");
            }
            
            // Fetch Chainlink Price
            AggregatorV3Interface dataFeed = AggregatorV3Interface(market.oracleFeed);
            (, int256 price, , , ) = dataFeed.latestRoundData();
            require(price > 0, "Invalid Oracle Price");

            if (price >= market.targetPrice) {
                market.outcome = MarketOutcome.Yes;
            } else {
                market.outcome = MarketOutcome.No;
            }
            emit MarketResolved(_marketId, market.outcome, price);

        } else {
            // --- 👤 MANUAL PATH ---
            if (isPriorityPeriod) {
                // Normal Case: Admin decides
                require(msg.sender == owner(), "Only Owner");
                market.outcome = _manualYesWin ? MarketOutcome.Yes : MarketOutcome.No;
                emit MarketResolved(_marketId, market.outcome, 0);
            } else {
                // 🚨 EMERGENCY CASE (> 3 Days & Admin Missing)
                // If it's manual and admin is gone, we VOID (Refund) the market.
                market.outcome = MarketOutcome.Void;
                emit MarketResolved(_marketId, MarketOutcome.Void, 0);
            }
        }

        market.resolved = true;
    }

    // --- CLAIMING (Updated to support Refunds/Void) ---
    function claimWinnings(uint256 _marketId) public {
        Market storage market = markets[_marketId];
        require(market.resolved, "Market not resolved");
        require(!hasClaimed[_marketId][msg.sender], "Already claimed");

        uint256 reward = 0;

        // 🔄 HANDLE REFUND (VOID)
        if (market.outcome == MarketOutcome.Void) {
            // Return exact bets (Yes + No)
            uint256 yesBet = bets[_marketId][msg.sender][1];
            uint256 noBet = bets[_marketId][msg.sender][0];
            reward = yesBet + noBet;
            require(reward > 0, "No bet to refund");
        } 
        // 🏆 HANDLE WINNERS
        else {
            uint256 userBet;
            uint256 winningPool;
            uint256 losingPool;

            if (market.outcome == MarketOutcome.Yes) {
                userBet = bets[_marketId][msg.sender][1];
                winningPool = market.totalYesAmount;
                losingPool = market.totalNoAmount;
            } else {
                userBet = bets[_marketId][msg.sender][0];
                winningPool = market.totalNoAmount;
                losingPool = market.totalYesAmount;
            }

            require(userBet > 0, "No winnings");
            // Standard V3 Formula
            reward = userBet + ((userBet * losingPool) / winningPool);
        }

        hasClaimed[_marketId][msg.sender] = true;
        balances[msg.sender] += reward; 
        
        emit BalanceUpdated(msg.sender, balances[msg.sender]);
        emit WinningsClaimed(_marketId, msg.sender, reward);
    }

    // --- READ FUNCTIONS (V3 Compatible) ---
    function getMarketCount() public view returns (uint256) {
        return markets.length;
    }

    // Returns V3 fields + New Oracle fields
    function getMarket(uint256 _id) public view returns (
        string memory question, 
        uint256 endTime, 
        uint256 totalYesAmount, 
        uint256 totalNoAmount, 
        bool resolved, 
        MarketOutcome outcome,
        int256 targetPrice,  // New
        address oracleFeed   // New
    ) {
        Market memory m = markets[_id];
        return (
            m.question, 
            m.endTime, 
            m.totalYesAmount, 
            m.totalNoAmount, 
            m.resolved, 
            m.outcome,
            m.targetPrice,
            m.oracleFeed
        );
    }

    function getUserBets(address _user) public view returns (uint256[] memory) {
        return userBets[_user];
    }
}