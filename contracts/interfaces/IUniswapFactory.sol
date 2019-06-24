pragma solidity ^0.5.8;

interface IUniswapFactory {
    function createExchange(address token) external returns (address);
    function getExchange(address token) external view returns (address);
}
