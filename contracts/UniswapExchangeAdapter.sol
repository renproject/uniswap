pragma solidity ^0.5.8;

import "./interfaces/IUniswapExchange.sol";
import "openzeppelin-solidity/contracts/token/ERC20/IERC20.sol";
import "darknode-sol/contracts/Shifter/Shifter.sol";

/// @notice funds should NEVER be transferred directly to this contract, as they 
///         would be lost forever.
/// @dev    this contract should not be deployed directly, allow the 
///         UniswapAdapterFactory to do the contract deployments.
contract UniswapExchangeAdapter {

    /// @notice this contract is associated with a single token.
    IERC20 token;

    /// @notice the uniswap exchange this contract would be communicating with.
    IUniswapExchange public exchange;  

    /// @notice the ren shifter this contract would be communicating with.
    Shifter public shifter;  

    /// @notice we treat this as the ethereum token address, to have one 
    ///         function signnature for trading ethereum and erc20 tokens.
    address public ethereum = address(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE);

    /// @notice initializes the exchange and shifter contracts, this contract 
    ///         would be communicating with. 
    constructor(IUniswapExchange _exchange, Shifter _shifter) public {
        exchange = _exchange;
        shifter = _shifter;
        token = IERC20(shifter.token());
    }

    /// @notice this function only allows the exchange contract to send eth to 
    ///         this contract, this protects users from sending ether to this 
    ///         contract by mistake.
    function () external payable {
        require(msg.sender == address(exchange), "only allow exchange to transfer eth into this contract");
    }

    /// @notice this function allows the trader to buy this contract's primary 
    ///         token with ether.
    /// @param _to the specific blockchain address to send the funds to.
    /// @param _minAmt min amount of this contract's primary token the trader is 
    ///         willing to accept.
    /// @param  _token is the token the trader wants to send.
    /// @param  _amount is the amount of token the trader is willing to spend.
    /// @param _deadline is the unix timestamp until which this transaction is 
    ///         valid till.
    function buy(
        bytes calldata _to, uint256 _minAmt, address _token, uint256 _amount,
        uint256 _deadline
    ) external payable 
        returns (uint256 tokensBought)
    {
        if (_token == ethereum) {
            return shifter.shiftOut(_to, exchange.ethToTokenSwapInput.value(msg.value)(_minAmt, _deadline));
        }
        return shifter.shiftOut(_to, exchange.tokenToTokenSwapInput(_amount, _minAmt, 0, _deadline, _token));
    }

    /// @notice this function allows the trader to sell this contract's primary 
    ///         token for ether.
    /// @param _amount the amount of the primary token the trader is willing to 
    ///         to spend.
    /// @param _nHash this is used by the ren shifter contract to guarentee the 
    ///         uniqueness of this request.
    /// @param _sig is the signature returned by RenVM.
    /// @param _relayFee is an optional parameter that would incentivize a third 
    ///         party to submit this transaction for the trader.
    /// @param _to is the address of the trader to which he/she wants to receive 
    ///         their funds.
    /// @param _minEth is the minimum amount of ethereum the user is willing to 
    ///         accept.
    /// @param _refundAddress is the specific blockchain address to refund the 
    ///         funds to on the expiry of this trade.
    /// @param _deadline is the unix timestamp until which this transaction is 
    ///         valid till.
    function sell(
        uint256 _amount, bytes32 _nHash, bytes calldata _sig,
        uint256 _relayFee, address payable _to,
        uint256 _minEth,  bytes calldata _refundAddress, uint256 _deadline
    ) external 
        returns (uint256 ethBought)
    {
        require(_minEth > _relayFee);

        bytes32 pHash = keccak256(abi.encode(_relayFee, _to, _minEth, _deadline, _refundAddress));
        uint256 shiftedAmount = shifter.shiftIn(_amount, _nHash, _sig, pHash);
        if (now > _deadline) {
            shifter.shiftOut(_refundAddress, shiftedAmount);
            return 0;
        }
        
        require(token.approve(address(exchange), shiftedAmount));
        ethBought = exchange.tokenToEthSwapInput(shiftedAmount, _minEth, _deadline);
        if (_relayFee > 0) {
            msg.sender.transfer(_relayFee);
        }
        _to.transfer(ethBought-_relayFee);
    }
}

