// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract GameCurrencySwap is ReentrancyGuard {
    IERC20 public immutable tokenA;
    IERC20 public immutable tokenB;
    
    uint256 public reserveA;
    uint256 public reserveB;
    uint256 public constant FEE_BPS = 30; // 0.3% fee
    uint256 public totalLiquidity;
    mapping(address => uint256) public liquidity;

    event Swap(address indexed user, address tokenIn, uint256 amountIn, address tokenOut, uint256 amountOut);
    event LiquidityAdded(address indexed provider, uint256 amountA, uint256 amountB);
    event LiquidityRemoved(address indexed provider, uint256 amountA, uint256 amountB);

    constructor(address _tokenA, address _tokenB) {
        tokenA = IERC20(_tokenA);
        tokenB = IERC20(_tokenB);
    }

    // Add liquidity to the pool
    function addLiquidity(uint256 amountA, uint256 amountB) external nonReentrant {
        require(amountA > 0 && amountB > 0, "Cannot add zero liquidity");
        
        // Transfer tokens from user
        tokenA.transferFrom(msg.sender, address(this), amountA);
        tokenB.transferFrom(msg.sender, address(this), amountB);

        // Calculate liquidity shares
        uint256 liquidityAmount;
        if (totalLiquidity == 0) {
            liquidityAmount = sqrt(amountA * amountB);
        } else {
            liquidityAmount = min(
                (amountA * totalLiquidity) / reserveA,
                (amountB * totalLiquidity) / reserveB
            );
        }
        
        // Update reserves and liquidity
        reserveA += amountA;
        reserveB += amountB;
        liquidity[msg.sender] += liquidityAmount;
        totalLiquidity += liquidityAmount;

        emit LiquidityAdded(msg.sender, amountA, amountB);
    }

    // Remove liquidity from the pool
    function removeLiquidity(uint256 liquidityAmount) external nonReentrant {
        require(liquidityAmount > 0, "Invalid liquidity amount");
        require(liquidity[msg.sender] >= liquidityAmount, "Insufficient liquidity");

        // Calculate proportional amounts
        uint256 amountA = (reserveA * liquidityAmount) / totalLiquidity;
        uint256 amountB = (reserveB * liquidityAmount) / totalLiquidity;
        
        // Update reserves and liquidity
        reserveA -= amountA;
        reserveB -= amountB;
        liquidity[msg.sender] -= liquidityAmount;
        totalLiquidity -= liquidityAmount;

        // Transfer tokens back to user
        tokenA.transfer(msg.sender, amountA);
        tokenB.transfer(msg.sender, amountB);

        emit LiquidityRemoved(msg.sender, amountA, amountB);
    }

    // Swap between tokens
    function swap(address tokenIn, uint256 amountIn) external nonReentrant returns (uint256 amountOut) {
        require(amountIn > 0, "Invalid input amount");
        require(tokenIn == address(tokenA) || tokenIn == address(tokenB), "Invalid token");

        (IERC20 tokenOut, uint256 inputReserve, uint256 outputReserve) = 
            (tokenIn == address(tokenA)) 
                ? (tokenB, reserveA, reserveB)
                : (tokenA, reserveB, reserveA);

        // Transfer input tokens from user
        IERC20(tokenIn).transferFrom(msg.sender, address(this), amountIn);

        // Calculate output amount with fee
        uint256 amountInWithFee = amountIn * (10000 - FEE_BPS);
        amountOut = (amountInWithFee * outputReserve) / 
                   ((inputReserve * 10000) + amountInWithFee);

        require(amountOut > 0, "Insufficient output amount");

        // Update reserves
        if (tokenIn == address(tokenA)) {
            reserveA += amountIn;
            reserveB -= amountOut;
        } else {
            reserveB += amountIn;
            reserveA -= amountOut;
        }

        // Transfer output tokens to user
        tokenOut.transfer(msg.sender, amountOut);

        emit Swap(msg.sender, tokenIn, amountIn, address(tokenOut), amountOut);
    }

    // Helper functions
    function sqrt(uint256 y) internal pure returns (uint256 z) {
        if (y > 3) {
            z = y;
            uint256 x = y / 2 + 1;
            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
            }
        } else if (y != 0) {
            z = 1;
        }
    }

    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }
}