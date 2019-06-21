pragma solidity ^0.5.8;

import "openzeppelin-solidity/contracts/token/ERC20/IERC20.sol";
import "darknode-sol/contracts/Shifter/Shifter.sol";

contract UniswapExchangeAdapter {
    IUniswapExchange public exchange;  
    Shifter public shifter;  
    constructor(IUniswapExchange _exchange, Shifter _shifter) public {
        exchange = _exchange;
        shifter = _shifter;
    }

    function sell(
        uint256 _minDstAmt, bytes calldata _to, uint256 _deadline
    ) external payable 
        returns (uint256 tokensBought)
    {
        return shifter.shiftOut(_to, exchange.ethToTokenSwapInput.value(msg.value)(_minDstAmt, _deadline));
    }

    function buy(
        uint256 _amount, bytes32 _nHash, bytes calldata _sig,
        uint256 _relayFee, address payable _to,
        uint256 _minEth, uint256 _deadline, bytes calldata _refundAddress
    ) external payable 
        returns (uint256 ethBought)
    {
        require(_minEth > _relayFee);
        bytes32 pHash = keccak256(abi.encode(_minEth, _deadline, _refundAddress));
        uint256 shiftedAmount = shifter.shiftIn(_amount, _nHash, _sig, pHash);
        if (block.number > _deadline) {
            shifter.shiftOut(_refundAddress, shiftedAmount);
            return 0;
        }
        ethBought = exchange.tokenToEthSwapInput(shiftedAmount, _minEth, _deadline);
        msg.sender.transfer(_relayFee);
        _to.transfer(ethBought-_relayFee);
        return ethBought;
    }
}

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

    function token() external view returns (address);
}