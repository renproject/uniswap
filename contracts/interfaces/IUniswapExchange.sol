pragma solidity ^0.5.8;

/// @notice IUniswapExchange is a solidity translation of UniswapExchange.vy's 
///         interface, original contract source code can be found at 
///         https://github.com/uniswap.
interface IUniswapExchange {
    function ethToTokenSwapInput(
        uint256 min_tokens,
        uint256 deadline
    )
        external
        payable
        returns (uint256  tokens_bought);

    function tokenToEthSwapInput(
        uint256 tokens_sold,
        uint256 min_eth,
        uint256 deadline
    )
        external
        returns (uint256  eth_bought);

    function tokenToTokenSwapInput(
        uint256 tokens_sold,
        uint256 min_tokens_bought,
        uint256 min_eth_bought,
        uint256 deadline,
        address token_addr
    )
        external
        returns (uint256  tokens_bought);

    function getEthToTokenInputPrice(
        uint256 eth_sold
    )
        external
        view
        returns (uint256 tokens_bought);

    function getTokenToEthInputPrice(
        uint256 tokens_sold
    )
        external
        view
        returns (uint256 eth_bought);
    
    function getTokenToTokenInputPrice(
        uint256 tokens_sold
    )
        external
        view
        returns (uint256 eth_bought);

    function tokenAddress() external view returns (address);
}