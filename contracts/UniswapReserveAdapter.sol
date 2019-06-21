pragma solidity ^0.5.8;

import "darknode-sol/contracts/Shifter/Shifter.sol";
import "openzeppelin-solidity/contracts/token/ERC20/IERC20.sol";


interface IUniswapReserve {
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

    function token() external view returns (address);
}