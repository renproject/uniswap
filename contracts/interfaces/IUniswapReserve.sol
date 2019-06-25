pragma solidity ^0.5.8;

import "openzeppelin-solidity/contracts/token/ERC20/IERC20.sol";

/// @notice IUniswapExchange is a solidity translation of UniswapExchange.vy's 
///         interface, original contract source code can be found at 
///         https://github.com/uniswap.
contract IUniswapReserve is IERC20 {
    function addLiquidity(
        uint256 min_liquidity, 
        uint256 max_tokens,
        uint256 deadline
    ) 
        external
        payable
        returns (uint256  uni_minted);

    function removeLiquidity(
        uint256 amount, 
        uint256 min_eth,
        uint256 min_tokens,
        uint256 deadline
    )   
        external
        payable
        returns (uint256  eth, uint256 tokens);

    function tokenAddress() external view returns (address);
}