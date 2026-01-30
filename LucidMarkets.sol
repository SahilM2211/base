// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

interface ILucidMath {
    struct Distribution { uint256 netPayout; uint256 totalFee; uint256 adminShare; uint256 refShare; }
    function calculate(uint256 u, uint256 t, uint256 w, uint256 f, uint256 r, bool h) external pure returns (Distribution memory);
}
interface ILucidResolver {
    function checkOutcome(address o, uint80 r, uint256 e, int256 t, bool l) external view returns (uint8, int256, bool);
}

contract LucidMarketsV2 is Ownable {
    using SafeERC20 for IERC20;

    // --- REENTRANCY LOCK ---
    uint256 private _locked = 1;
    modifier nonReentrant() {
        require(_locked == 1, "Reentrant");
        _locked = 2;
        _;
        _locked = 1;
    }

    // --- EXTERNAL CONTRACTS ---
    ILucidMath public math;
    ILucidResolver public resolver;

    enum MarketOutcome { PENDING, NO, YES, VOID }

    // 📦 STRUCT 1: SETTINGS (Static)
    // "What is the bet about?"
    struct MarketConfig {
        string question;
        string metadataURI;
        uint256 endTime;
        int256 targetPrice;
        address oracleFeed;
        address bettingToken;
        bool isLessThan;
    }

    // 📦 STRUCT 2: STATUS (Dynamic)
    // "Where is the money?"
    struct MarketStatus {
        bool resolved;
        bool cancelled;
        MarketOutcome outcome;
        uint256 totalPool;
        uint256 totalYes;
        uint256 totalNo;
        uint256 winningPool;
    }

    struct BetInfo {
        uint256 yesAmount;
        uint256 noAmount;
        address referrer;
        bool claimed;
    }

    // --- STATE VARIABLES ---
    uint256 public marketCount;
    uint256 public totalFee = 500;      
    uint256 public referralShare = 100; 
    uint256 public minBetAmount = 0.001 ether; 
    address public treasury; 
    bool public isPaused; 

    // 🔥 SPLIT MAPPINGS (Fixes Stack Error)
    mapping(uint256 => MarketConfig) public marketConfigs;
    mapping(uint256 => MarketStatus) public marketStatuses;
    mapping(uint256 => mapping(address => BetInfo)) public userBets;
    mapping(address => bool) public allowedTokens; 

    // --- EVENTS ---
    event MarketCreated(uint256 indexed marketId, string question, address indexed token);
    event BetPlaced(uint256 indexed marketId, address indexed user, uint256 amount, bool isYes, address referrer);
    event MarketResolved(uint256 indexed marketId, MarketOutcome outcome, int256 finalPrice, uint256 poolSize);
    event WinningsClaimed(uint256 indexed marketId, address indexed user, uint256 amount, uint256 feePaid);
    event MarketCancelled(uint256 indexed marketId);
    event FeesDistributed(uint256 indexed marketId, uint256 adminAmount, uint256 referrerAmount, address referrer);

    constructor(address _math, address _resolver) Ownable(msg.sender) {
        math = ILucidMath(_math);
        resolver = ILucidResolver(_resolver);
        treasury = msg.sender;
    }

    // --- 1. CREATE MARKET ---
    // Takes the Config Struct directly as input
    function createMarket(MarketConfig calldata params) external onlyOwner {
        marketCount++;
        
        // Save to Config Mapping
        marketConfigs[marketCount] = params;
        
        // Status Mapping starts empty/default
        
        emit MarketCreated(marketCount, params.question, params.bettingToken);
    }

    // --- 2. PLACE BET ---
    function placeBet(uint256 _id, bool _isYes, uint256 _amt, address _ref) external payable nonReentrant {
        // Validation Scope
        {
            require(!isPaused, "Paused");
            MarketStatus storage s = marketStatuses[_id];
            MarketConfig storage c = marketConfigs[_id];
            
            require(!s.resolved && !s.cancelled && block.timestamp < c.endTime, "Invalid");
            require(_amt >= minBetAmount, "Low Bet");
            
            if (c.bettingToken == address(0)) require(msg.value == _amt, "ETH Fail");
            else IERC20(c.bettingToken).safeTransferFrom(msg.sender, address(this), _amt);
        }

        // Logic Scope
        {
            BetInfo storage bet = userBets[_id][msg.sender];
            if(bet.referrer == address(0) && _ref != address(0) && _ref != msg.sender) bet.referrer = _ref;

            MarketStatus storage s = marketStatuses[_id];
            if (_isYes) { bet.yesAmount += _amt; s.totalYes += _amt; }
            else { bet.noAmount += _amt; s.totalNo += _amt; }
            s.totalPool += _amt;
            
            emit BetPlaced(_id, msg.sender, _amt, _isYes, bet.referrer);
        }
    }

    // --- 3. RESOLVE ---
    function resolveMarket(uint256 _id, uint80 _roundId) external onlyOwner {
        MarketStatus storage s = marketStatuses[_id];
        require(!s.resolved, "Resolved");

        // Load Config separately to save stack
        MarketConfig storage c = marketConfigs[_id];

        (uint8 winCode, int256 price, bool valid) = resolver.checkOutcome(
            c.oracleFeed, _roundId, c.endTime, c.targetPrice, c.isLessThan
        );
        require(valid, "Invalid Round");

        s.outcome = (winCode == 2) ? MarketOutcome.YES : MarketOutcome.NO;
        s.resolved = true;
        s.winningPool = (s.outcome == MarketOutcome.YES) ? s.totalYes : s.totalNo;

        if (s.winningPool == 0 && s.totalPool > 0) {
             _payout(c.bettingToken, treasury, s.totalPool);
        }
        emit MarketResolved(_id, s.outcome, price, s.totalPool);
    }

    // --- 4. CLAIM ---
    function claimWinnings(uint256 _id) external nonReentrant {
        MarketStatus storage s = marketStatuses[_id];
        BetInfo storage bet = userBets[_id][msg.sender];
        require(s.resolved && !bet.claimed && !s.cancelled, "Invalid");

        uint256 stake = (s.outcome == MarketOutcome.YES) ? bet.yesAmount : ((s.outcome == MarketOutcome.NO) ? bet.noAmount : 0);
        require(stake > 0, "No Win");
        bet.claimed = true;

        ILucidMath.Distribution memory d = math.calculate(
            stake, s.totalPool, s.winningPool, totalFee, referralShare, (bet.referrer != address(0))
        );

        address token = marketConfigs[_id].bettingToken;
        _payout(token, msg.sender, d.netPayout);
        
        if(d.totalFee > 0) {
            _payout(token, treasury, d.adminShare);
            if(d.refShare > 0) _payout(token, bet.referrer, d.refShare);
            emit FeesDistributed(_id, d.adminShare, d.refShare, bet.referrer);
        }
        emit WinningsClaimed(_id, msg.sender, d.netPayout, d.totalFee);
    }

    // --- ADMIN ---
    function cancelMarket(uint256 _id) external onlyOwner {
        marketStatuses[_id].cancelled = true; 
        marketStatuses[_id].resolved = true; 
        marketStatuses[_id].outcome = MarketOutcome.VOID;
        emit MarketCancelled(_id);
    }
    
    function emergencyRefund(uint256 _id) external nonReentrant {
        MarketStatus storage s = marketStatuses[_id];
        MarketConfig storage c = marketConfigs[_id];
        require(!s.resolved && block.timestamp > c.endTime + 3 days);
        _refund(_id, c.bettingToken);
    }

    function withdrawCancelled(uint256 _id) external nonReentrant {
        MarketStatus storage s = marketStatuses[_id];
        require(s.cancelled || s.outcome == MarketOutcome.VOID);
        _refund(_id, marketConfigs[_id].bettingToken);
    }

    function _refund(uint256 _id, address _token) internal {
        BetInfo storage bet = userBets[_id][msg.sender];
        uint256 total = bet.yesAmount + bet.noAmount;
        require(total > 0 && !bet.claimed);
        bet.claimed = true;
        _payout(_token, msg.sender, total);
    }

    function sweepUnclaimed(uint256 _id) external onlyOwner {
        require(marketStatuses[_id].resolved && block.timestamp > marketConfigs[_id].endTime + 365 days);
        address token = marketConfigs[_id].bettingToken;
        if(token == address(0)) _payout(address(0), treasury, address(this).balance);
        else IERC20(token).safeTransfer(treasury, IERC20(token).balanceOf(address(this)));
    }

    function _payout(address t, address to, uint256 a) internal {
        if(t == address(0)) { (bool s,) = to.call{value: a}(""); require(s); }
        else IERC20(t).safeTransfer(to, a);
    }

    // Setters
    function setPaused(bool _s) external onlyOwner { isPaused = _s; }
    function setTreasury(address _t) external onlyOwner { treasury = _t; }
    function setMath(address _m) external onlyOwner { math = ILucidMath(_m); }
    function setResolver(address _r) external onlyOwner { resolver = ILucidResolver(_r); }
    
    receive() external payable {}
}