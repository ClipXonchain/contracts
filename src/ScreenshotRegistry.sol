// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

/**
 * @title ScreenshotRegistry
 * @notice Stores on-chain proof of screenshots and allows secure fund handling.
 * @dev Includes safe fund transfer, ownership control, and data validation.
 */
contract ScreenshotRegistry {
    struct Proof {
        string cid;         // IPFS CID of screenshot
        uint256 timestamp;  // When it was recorded
        string tweetId;     // Associated tweet ID
        address recorder;   // Address that submitted it
    }

    // cid -> Proof data
    mapping(string => Proof) private proofs;
    // tweetId -> cid (for quick lookup)
    mapping(string => string) private cidByTweetId;

    // --- Events ---
    event ScreenshotRegistered(string indexed cid, string indexed tweetId, address indexed recorder, uint256 timestamp);
    event FundsReceived(address indexed from, uint256 amount);
    event FundsWithdrawn(address indexed to, uint256 amount);
    event FundsTransferred(address indexed from, address indexed to, uint256 amount);
    event OwnerChanged(address indexed oldOwner, address indexed newOwner);

    // --- Ownership ---
    address public owner;

    constructor() {
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Not contract owner");
        _;
    }

    // --- Core Proof Functions ---

    /**
     * @notice Register a new screenshot proof.
     * @param _cid IPFS CID of the screenshot.
     * @param _tweetId Associated tweet ID.
     */
    function registerScreenshot(string calldata _cid, string calldata _tweetId) external {
        require(bytes(_cid).length > 0, "CID required");
        require(bytes(_tweetId).length > 0, "Tweet ID required");
        require(bytes(cidByTweetId[_tweetId]).length == 0, "Tweet already registered");

        Proof storage p = proofs[_cid];
        require(p.timestamp == 0, "CID already registered");

        p.cid = _cid;
        p.tweetId = _tweetId;
        p.timestamp = block.timestamp;
        p.recorder = msg.sender;

        cidByTweetId[_tweetId] = _cid;

        emit ScreenshotRegistered(_cid, _tweetId, msg.sender, block.timestamp);
    }

    /**
     * @notice Verify proof by CID.
     */
    function verifyScreenshot(string calldata _cid)
        external
        view
        returns (uint256 timestamp, string memory tweetId, address recorder)
    {
        Proof memory p = proofs[_cid];
        return (p.timestamp, p.tweetId, p.recorder);
    }

    /**
     * @notice Retrieve proof by Tweet ID.
     */
    function getProofByTweetId(string calldata _tweetId)
        external
        view
        returns (string memory cid, uint256 timestamp, address recorder)
    {
        string memory c = cidByTweetId[_tweetId];
        Proof memory p = proofs[c];
        return (c, p.timestamp, p.recorder);
    }

    // --- Fund Handling ---

    /**
     * @notice Allow contract to receive BNB.
     */
    receive() external payable {
        emit FundsReceived(msg.sender, msg.value);
    }

    fallback() external payable {
        emit FundsReceived(msg.sender, msg.value);
    }

    /**
     * @notice Withdraw all funds to owner address.
     */
    function withdrawFunds() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No funds available");

        (bool sent, ) = payable(owner).call{value: balance}("");
        require(sent, "Withdraw failed");

        emit FundsWithdrawn(owner, balance);
    }

    /**
     * @notice Transfer specific amount to another address.
     * @param _to Recipient address.
     * @param _amount Amount in wei.
     */
    function transferFunds(address payable _to, uint256 _amount) external onlyOwner {
        require(_to != address(0), "Invalid address");
        require(_amount <= address(this).balance, "Insufficient funds");

        (bool sent, ) = _to.call{value: _amount}("");
        require(sent, "Transfer failed");

        emit FundsTransferred(owner, _to, _amount);
    }

    /**
     * @notice View contract’s BNB balance.
     */
    function getBalance() external view returns (uint256) {
        return address(this).balance;
    }

    /**
     * @notice Change ownership of the contract.
     * @param newOwner Address of the new owner.
     */
    function changeOwner(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Invalid new owner");
        emit OwnerChanged(owner, newOwner);
        owner = newOwner;
    }
}
