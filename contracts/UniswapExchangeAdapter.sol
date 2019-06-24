pragma solidity ^0.5.8;

import "./IUniswapExchange.sol";
import "openzeppelin-solidity/contracts/token/ERC20/IERC20.sol";
import "darknode-sol/contracts/Shifter/Shifter.sol";

contract UniswapExchangeAdapter {
    IUniswapExchange public exchange;  
    Shifter public shifter;  
    address public ethereum = address(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE);

    constructor(IUniswapExchange _exchange, Shifter _shifter) public {
        exchange = _exchange;
        shifter = _shifter;
    }

    function () external payable {
        require(msg.sender == address(exchange), "only allow exchange to transfer eth into this contract");
    }

    function buy(
        uint256 _minAmt, bytes calldata _to, uint256 _deadline,
        address _token, uint256 _amount
    ) external payable 
        returns (uint256 tokensBought)
    {
        if (_token == ethereum) {
            return shifter.shiftOut(_to, exchange.ethToTokenSwapInput.value(msg.value)(_minAmt, _deadline));
        }
        return shifter.shiftOut(_to, exchange.tokenToTokenSwapInput(_amount, _minAmt, 0, _deadline, _token));
    }

    function sell(
        uint256 _amount, bytes32 _nHash, bytes calldata _sig,
        uint256 _relayFee, address payable _to,
        uint256 _minEth, uint256 _deadline, bytes calldata _refundAddress
    ) external payable 
        returns (uint256 ethBought)
    {
        require(_minEth > _relayFee);

        bytes32 pHash = keccak256(abi.encode(_relayFee, _to, _minEth, _deadline, _refundAddress));
        uint256 shiftedAmount = shifter.shiftIn(_amount, _nHash, _sig, pHash);
        if (now > _deadline) {
            shifter.shiftOut(_refundAddress, shiftedAmount);
            return 0;
        }
        
        require(IERC20(shifter.token()).approve(address(exchange), shiftedAmount));
        ethBought = exchange.tokenToEthSwapInput(shiftedAmount, _minEth, _deadline);
        if (_relayFee > 0) {
            msg.sender.transfer(_relayFee);
        }
        _to.transfer(ethBought-_relayFee);
    }
}

