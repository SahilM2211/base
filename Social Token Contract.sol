// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title SocialToken
 * @dev An ERC20 token that stores its own social metadata on-chain.
 * Supply: 1,000,000,000 (1 Billion)
 */
contract SocialToken is ERC20, Ownable {

    // --- On-Chain Metadata ---
    string public tokenDescription;
    string public xProfileUrl;    // e.g. https://x.com/mytoken
    string public websiteUrl;     // e.g. https://mytoken.com
    string public logoUrl;        // e.g. https://ipfs.io/... or https://mysite.com/logo.png

    event MetadataUpdated(string field, string newValue);

    /**
     * @dev Constructor sets up the token and the initial metadata.
     * @param _name Token Name (e.g. "Super Coin")
     * @param _symbol Token Symbol (e.g. "SUP")
     * @param _desc Short description of the project
     * @param _xUrl Link to X/Twitter
     * @param _webUrl Link to Website
     * @param _logoUrl Link to an image file (PNG/JPG)
     */
    constructor(
        string memory _name,
        string memory _symbol,
        string memory _desc,
        string memory _xUrl,
        string memory _webUrl,
        string memory _logoUrl
    ) ERC20(_name, _symbol) Ownable(msg.sender) {
        
        // Mint 1 Billion tokens to the deployer
        // 1_000_000_000 * 10^18 (standard decimals)
        _mint(msg.sender, 1000000000 * 10**decimals());

        // Set initial metadata
        tokenDescription = _desc;
        xProfileUrl = _xUrl;
        websiteUrl = _webUrl;
        logoUrl = _logoUrl;
    }

    // --- Owner Functions to Update Metadata ---

    function setDescription(string memory _desc) public onlyOwner {
        tokenDescription = _desc;
        emit MetadataUpdated("Description", _desc);
    }

    function setXProfile(string memory _url) public onlyOwner {
        xProfileUrl = _url;
        emit MetadataUpdated("X Profile", _url);
    }

    function setWebsite(string memory _url) public onlyOwner {
        websiteUrl = _url;
        emit MetadataUpdated("Website", _url);
    }

    function setLogo(string memory _url) public onlyOwner {
        logoUrl = _url;
        emit MetadataUpdated("Logo", _url);
    }
}