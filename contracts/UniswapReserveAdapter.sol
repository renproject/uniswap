pragma solidity ^0.5.8;

import "./IUniswapReserve.sol";
import "darknode-sol/contracts/Shifter/Shifter.sol";
import "openzeppelin-solidity/contracts/token/ERC20/IERC20.sol";

contract UniswapReserveAdapter {
    IUniswapReserve public reserve;  
    Shifter public shifter;  
    constructor(IUniswapReserve _reserve, Shifter _shifter) public {
        reserve = _reserve;
        shifter = _shifter;
    }

    function () external payable {
        require(msg.sender == address(reserve), "only allow reserve to transfer eth into this contract");
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

        if (now > _deadline) {
            shifter.shiftOut(_refundAddress, amount);
            return 0;
        }

        IERC20 token = IERC20(reserve.tokenAddress());
        token.approve(address(reserve), _amount);
        uniMinted = reserve.addLiquidity.value(msg.value)(_minLiquidity, amount, _deadline);
        IERC20(address(reserve)).transfer(msg.sender, uniMinted);

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
        require(IERC20(address(reserve)).transferFrom(msg.sender, address(this), _uniAmount), "uni allowance not provided");
        (eth, tokens) = reserve.removeLiquidity(_uniAmount, _minEth, _minTokens, _deadline);
        msg.sender.transfer(eth);
        tokens = shifter.shiftOut(_to, tokens);
    }
}

