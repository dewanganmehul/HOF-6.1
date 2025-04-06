// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transferFrom(address from, address to, uint256 value) external returns (bool);
    function transfer(address to, uint256 value) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

contract GameCurrencyPool {
    address public admin;

    // Track supported tokens (ERC20 in-game currencies)
    mapping(address => bool) public supportedTokens;

    // Player balances per token
    mapping(address => mapping(address => uint256)) public playerBalances; // user => token => amount

    modifier onlyAdmin() {
        require(msg.sender == admin, "Not authorized");
        _;
    }

    event TokenSupported(address token);
    event Deposited(address indexed user, address token, uint256 amount);
    event Exchanged(address indexed user, address fromToken, address toToken, uint256 amount);
    event Withdrawn(address indexed user, address token, uint256 amount);

    constructor() {
        admin = msg.sender;
    }

    // Admin adds a supported token (e.g., G1T, G2T, etc.)
    function addSupportedToken(address token) external onlyAdmin {
        require(token != address(0), "Invalid token address");
        supportedTokens[token] = true;
        emit TokenSupported(token);
    }

    // Deposit in-game currency to the pool
    function deposit(address token, uint256 amount) external {
        require(supportedTokens[token], "Token not supported");
        require(IERC20(token).transferFrom(msg.sender, address(this), amount), "Transfer failed");

        playerBalances[msg.sender][token] += amount;

        emit Deposited(msg.sender, token, amount);
    }

    // Exchange one supported token to another at 1:1 value
    function exchange(address fromToken, address toToken, uint256 amount) external {
        require(supportedTokens[fromToken] && supportedTokens[toToken], "Tokens must be supported");
        require(fromToken != toToken, "Cannot exchange same token");
        require(playerBalances[msg.sender][fromToken] >= amount, "Insufficient balance");

        // Check if enough liquidity of the target token
        require(IERC20(toToken).balanceOf(address(this)) >= amount, "Insufficient pool liquidity");

        // Deduct from sender's internal balance
        playerBalances[msg.sender][fromToken] -= amount;
        playerBalances[msg.sender][toToken] += amount;

        emit Exchanged(msg.sender, fromToken, toToken, amount);
    }

    // Withdraw tokens to player wallet
    function withdraw(address token, uint256 amount) external {
        require(playerBalances[msg.sender][token] >= amount, "Insufficient balance");

        playerBalances[msg.sender][token] -= amount;
        require(IERC20(token).transfer(msg.sender, amount), "Transfer failed");

        emit Withdrawn(msg.sender, token, amount);
    }

    // View user balance for a specific token
    function getUserBalance(address user, address token) external view returns (uint256) {
        return playerBalances[user][token];
    }
}