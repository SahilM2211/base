// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import ".deps/npm/@openzeppelin/contracts/security/ReentrancyGuard.sol";

/**
 * @title BaseTrade Protocol
 * @dev Enterprise-grade Decentralized Letter of Credit (Trade Finance).
 * Secures international imports/exports by locking buyer funds in escrow,
 * releasing them only when a designated Inspector/Freight Forwarder verifies delivery.
 */
contract BaseTrade is ReentrancyGuard {

    enum TradeState { Draft, Funded, Shipped, Completed, Disputed, Refunded }

    struct Trade {
        uint256 id;
        address buyer;           // Importer
        address seller;          // Exporter
        address inspector;       // Customs / Freight Forwarder / Quality Control
        string goodsDescription; // e.g., "10 Pallets of Solar Panels"
        uint256 amount;          // Contract value in Wei
        uint256 expiryDate;      // Max date for goods to arrive
        TradeState state;
    }

    uint256 public tradeCounter;
    mapping(uint256 => Trade) public trades;

    // --- Events for Logistics Tracking ---
    event TradeDrafted(uint256 indexed id, address indexed buyer, address indexed seller, uint256 amount);
    event TradeFunded(uint256 indexed id);
    event GoodsShipped(uint256 indexed id);
    event GoodsApprovedAndPaid(uint256 indexed id, address indexed seller, uint256 amount);
    event GoodsRejected(uint256 indexed id, string reason);
    event DisputeRaised(uint256 indexed id, address raisedBy);
    event TradeRefunded(uint256 indexed id, address indexed buyer);

    /**
     * @dev 1. Buyer (Importer) drafts the commercial invoice / trade agreement.
     */
    function draftTrade(
        address _seller,
        address _inspector,
        string memory _goodsDescription,
        uint256 _amountWei,
        uint256 _daysToExpiry
    ) public {
        require(_seller != address(0) && _inspector != address(0), "Invalid addresses");
        require(_seller != msg.sender && _inspector != msg.sender, "Roles must be unique");
        require(_amountWei > 0, "Trade value must be > 0");

        uint256 tradeId = tradeCounter++;
        
        trades[tradeId] = Trade({
            id: tradeId,
            buyer: msg.sender,
            seller: _seller,
            inspector: _inspector,
            goodsDescription: _goodsDescription,
            amount: _amountWei,
            expiryDate: block.timestamp + (_daysToExpiry * 1 days),
            state: TradeState.Draft
        });

        emit TradeDrafted(tradeId, msg.sender, _seller, _amountWei);
    }

    /**
     * @dev 2. Buyer locks the funds in the contract (The "Letter of Credit").
     */
    function fundTrade(uint256 _tradeId) public payable nonReentrant {
        Trade storage trade = trades[_tradeId];
        require(msg.sender == trade.buyer, "Only buyer can fund");
        require(trade.state == TradeState.Draft, "Trade already funded or invalid state");
        require(msg.value == trade.amount, "Must deposit exact trade amount");

        trade.state = TradeState.Funded;
        emit TradeFunded(_tradeId);
    }

    /**
     * @dev 3. Seller (Exporter) marks the goods as shipped after verifying funds are locked.
     */
    function markShipped(uint256 _tradeId) public {
        Trade storage trade = trades[_tradeId];
        require(msg.sender == trade.seller, "Only seller can mark shipped");
        require(trade.state == TradeState.Funded, "Funds not locked yet");

        trade.state = TradeState.Shipped;
        emit GoodsShipped(_tradeId);
    }

    /**
     * @dev 4a. Happy Path: Inspector verifies goods at destination port. Funds auto-release to seller.
     */
    function approveGoods(uint256 _tradeId) public nonReentrant {
        Trade storage trade = trades[_tradeId];
        require(msg.sender == trade.inspector || msg.sender == trade.buyer, "Only inspector or buyer can approve");
        require(trade.state == TradeState.Shipped || trade.state == TradeState.Funded, "Invalid state for approval");

        trade.state = TradeState.Completed;

        (bool success, ) = trade.seller.call{value: trade.amount}("");
        require(success, "Payment transfer failed");

        emit GoodsApprovedAndPaid(_tradeId, trade.seller, trade.amount);
    }

    /**
     * @dev 4b. Sad Path: Inspector rejects goods (damaged/counterfeit). Dispute begins.
     */
    function rejectGoods(uint256 _tradeId, string memory _reason) public {
        Trade storage trade = trades[_tradeId];
        require(msg.sender == trade.inspector, "Only inspector can reject");
        require(trade.state == TradeState.Shipped, "Goods not shipped yet");

        trade.state = TradeState.Disputed;
        emit GoodsRejected(_tradeId, _reason);
    }

    /**
     * @dev 5. Inspector resolves dispute by splitting funds (e.g., 50% refund, 50% pay for partial damage).
     */
    function resolveDispute(uint256 _tradeId, uint256 _buyerShare, uint256 _sellerShare) public nonReentrant {
        Trade storage trade = trades[_tradeId];
        require(msg.sender == trade.inspector, "Only inspector can resolve");
        require(trade.state == TradeState.Disputed, "Trade is not in dispute");
        require(_buyerShare + _sellerShare == trade.amount, "Shares must equal total amount");

        trade.state = TradeState.Completed; // Marks end of contract lifecycle

        if (_buyerShare > 0) {
            (bool successB, ) = trade.buyer.call{value: _buyerShare}("");
            require(successB, "Buyer refund failed");
        }
        if (_sellerShare > 0) {
            (bool successS, ) = trade.seller.call{value: _sellerShare}("");
            require(successS, "Seller payment failed");
        }

        emit GoodsApprovedAndPaid(_tradeId, trade.seller, _sellerShare);
        emit TradeRefunded(_tradeId, trade.buyer);
    }

    /**
     * @dev 6. Time-lock protection: If goods never arrive by expiry date, Buyer can recall funds.
     */
    function recallExpiredFunds(uint256 _tradeId) public nonReentrant {
        Trade storage trade = trades[_tradeId];
        require(msg.sender == trade.buyer, "Only buyer can recall");
        require(trade.state == TradeState.Funded || trade.state == TradeState.Shipped, "Invalid state");
        require(block.timestamp > trade.expiryDate, "Trade has not expired yet");

        trade.state = TradeState.Refunded;

        (bool success, ) = trade.buyer.call{value: trade.amount}("");
        require(success, "Refund failed");

        emit TradeRefunded(_tradeId, trade.buyer);
    }

    // --- View Helpers ---
    function getTrade(uint256 _id) public view returns (Trade memory) {
        return trades[_id];
    }
}