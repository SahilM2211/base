
// File: @openzeppelin/contracts/utils/Context.sol


// OpenZeppelin Contracts (last updated v5.0.1) (utils/Context.sol)

pragma solidity ^0.8.20;

/**
 * @dev Provides information about the current execution context, including the
 * sender of the transaction and its data. While these are generally available
 * via msg.sender and msg.data, they should not be accessed in such a direct
 * manner, since when dealing with meta-transactions the account sending and
 * paying for execution may not be the actual sender (as far as an application
 * is concerned).
 *
 * This contract is only required for intermediate, library-like contracts.
 */
abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }

    function _contextSuffixLength() internal view virtual returns (uint256) {
        return 0;
    }
}

// File: @openzeppelin/contracts/access/Ownable.sol


// OpenZeppelin Contracts (last updated v5.0.0) (access/Ownable.sol)

pragma solidity ^0.8.20;


/**
 * @dev Contract module which provides a basic access control mechanism, where
 * there is an account (an owner) that can be granted exclusive access to
 * specific functions.
 *
 * The initial owner is set to the address provided by the deployer. This can
 * later be changed with {transferOwnership}.
 *
 * This module is used through inheritance. It will make available the modifier
 * `onlyOwner`, which can be applied to your functions to restrict their use to
 * the owner.
 */
abstract contract Ownable is Context {
    address private _owner;

    /**
     * @dev The caller account is not authorized to perform an operation.
     */
    error OwnableUnauthorizedAccount(address account);

    /**
     * @dev The owner is not a valid owner account. (eg. `address(0)`)
     */
    error OwnableInvalidOwner(address owner);

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the address provided by the deployer as the initial owner.
     */
    constructor(address initialOwner) {
        if (initialOwner == address(0)) {
            revert OwnableInvalidOwner(address(0));
        }
        _transferOwnership(initialOwner);
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        _checkOwner();
        _;
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view virtual returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if the sender is not the owner.
     */
    function _checkOwner() internal view virtual {
        if (owner() != _msgSender()) {
            revert OwnableUnauthorizedAccount(_msgSender());
        }
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby disabling any functionality that is only available to the owner.
     */
    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        if (newOwner == address(0)) {
            revert OwnableInvalidOwner(address(0));
        }
        _transferOwnership(newOwner);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Internal function without access restriction.
     */
    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

// File: base mainnet/Prediction Market Contract.sol


pragma solidity ^0.8.20;

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