pragma solidity ^0.5.8;

/// @notice IUniswapFactory is a solidity translation of UniswapFactory.vy's 
///         interface, original contract source code can be found at 
///         https://github.com/uniswap.
interface IUniswapFactory {
    function createExchange(address token) external returns (address);
    function getExchange(address token) external view returns (address);
}
