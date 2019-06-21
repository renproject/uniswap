pragma solidity ^0.5.8;

import "darknode-sol/contracts/Shifter/Shifter.sol";
import "openzeppelin-solidity/contracts/token/ERC20/IERC20.sol";

contract UniswapReserveAdapter {
    IUniswapReserve public reserve;  
    Shifter public shifter;  
    constructor(IUniswapReserve _reserve, Shifter _shifter) public {
        reserve = _reserve;
        shifter = _shifter;
    }

    function addLiquidity(
        uint256 _amount, bytes32 _nHash, bytes calldata _sig,
        uint256 _minLiquidity, uint256 _deadline, bytes calldata _refundAddress
        ) 
            external 
            payable 
            returns (uint256  uniMinted) 
        {
        bytes32 pHash = keccak256(abi.encode(_minLiquidity, _deadline, _refundAddress));
        uint256 amount = shifter.shiftIn(_amount, _nHash, _sig, pHash);

        if (block.number > _deadline) {
            shifter.shiftOut(_refundAddress, amount);
            return 0;
        }

        IERC20 token = IERC20(reserve.token());
        token.approve(address(reserve), _amount);
        uniMinted = reserve.addLiquidity.value(msg.value)(_minLiquidity, amount, _deadline);

        uint256 balance = token.balanceOf(address(this));
        if ( balance > 0 ) {
            shifter.shiftOut(_refundAddress, balance);
        }
        return uniMinted;
    }

    function removeLiquidity(
            uint256 _uniAmount, uint256 _minEth, uint256 _minTokens,
            uint256 _deadline, bytes calldata _to
        ) 
            external 
            payable 
            returns (uint256  eth, uint256 tokens)
        {
        (uint256 ethAmount, uint256 tokenAmount) = reserve.removeLiquidity(_uniAmount, _minEth, _minTokens, _deadline);
        msg.sender.transfer(ethAmount);
        uint256 shiftedAmount = shifter.shiftOut(_to, tokenAmount);
        return (ethAmount, shiftedAmount);
    }
}

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