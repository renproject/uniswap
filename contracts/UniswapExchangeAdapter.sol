pragma solidity ^0.5.8;

import "./interfaces/IUniswapExchange.sol";
import "openzeppelin-solidity/contracts/token/ERC20/IERC20.sol";
import "darknode-sol/contracts/Shifter/Shifter.sol";

/// @notice Funds should NEVER be transferred directly to this contract, as they 
///         would be lost forever.
/// @dev    Do not deploy this contract directly, allow the 
///         UniswapAdapterFactory to do the contract deployments.
contract UniswapExchangeAdapter {

    /// @notice This contract is associated with a single token, the primary 
    ///         token of this contract.
    IERC20 token;

    /// @notice The uniswap exchange this contract would be communicating with.
    IUniswapExchange public exchange;  

    /// @notice The ren shifter this contract would be communicating with.
    Shifter public shifter;  

    /// @dev    We treat this as the ethereum token address, to have one 
    ///         function signnature for trading ethereum and erc20 tokens.
    /// @notice Ethereum token address.
    address public ethereum = address(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE);

    /// @notice Initialize the exchange and shifter contracts, this contract 
    ///         would be communicating with. 
    constructor(IUniswapExchange _exchange, Shifter _shifter) public {
        exchange = _exchange;
        shifter = _shifter;
        token = IERC20(shifter.token());
    }

    /// @notice this function only allows the exchange contract to send eth to 
    ///         this contract, this protects users from accidenntally sending 
    ///         ether to this contract.
    function () external payable {
        require(msg.sender == address(exchange), "only allow exchange to transfer eth into this contract");
    }

    /// @notice Allow the trader to buy this contract's primary token with 
    ///         ether or any other token supported by Uniswap.
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
        returns (uint256)
    {
        if (_token == ethereum) {
            // Buy this contract's primary token with ether, and shift the 
            // token out on to it's native blockchain.
            return shifter.shiftOut(_to, exchange.ethToTokenSwapInput.value(msg.value)(_minAmt, _deadline));
        }

        // Buy this contract's primary token with _token, and shift the token
        // out on to it's native blockchain.
        return shifter.shiftOut(_to, exchange.tokenToTokenSwapInput(_amount, _minAmt, 0, _deadline, _token));
    }

    /// @notice Allow the trader to sell this contract's primary token for ether.
    /// @param _relayFee An optional fee to incentivize a third party to submit 
    ///         this transaction for the trader.
    /// @param _to The address of the trader to which he/she wants to receive 
    ///         their funds.
    /// @param _minEth The minimum amount of ethereum the user is willing to 
    ///         accept.
    /// @param _refundAddress The specific blockchain address to refund the 
    ///         funds to on the expiry of this trade.
    /// @param _deadline The unix timestamp until which this transaction is 
    ///         valid till.
    /// @param _amount The amount of the primary token the trader is willing to 
    ///         to spend.
    /// @param _nHash This is used by the ren shifter contract to guarentee the 
    ///         uniqueness of this request.
    /// @param _sig The signature returned by RenVM.
    function sell(
        uint256 _relayFee, address payable _to,
        uint256 _minEth,  bytes calldata _refundAddress, uint256 _deadline,
        uint256 _amount, bytes32 _nHash, bytes calldata _sig
    ) external 
        returns (uint256 ethBought)
    {
        require(_minEth >= _relayFee);

        // Calcualte the payload hash from the user input.
        bytes32 pHash = keccak256(abi.encode(_relayFee, _to, _minEth, _refundAddress, _deadline));
        
        uint256 shiftedAmount = shifter.shiftIn(pHash, _amount, _nHash, _sig);

        // If this deadline passes ERC20Shifted tokens are shifted in and
        // shifted out immediately.
        if (now > _deadline) {
            shifter.shiftOut(_refundAddress, shiftedAmount);
            return 0;
        }
        
        // Approve and trade the shifted tokens with the uniswap exchange.
        require(token.approve(address(exchange), shiftedAmount));
        ethBought = exchange.tokenToEthSwapInput(shiftedAmount, _minEth, _deadline);
        
        // transfer the resultant funds to the trader, and pay the relay fees to
        // the tx relayer.
        if (_relayFee > 0) {
            msg.sender.transfer(_relayFee);
        }
        _to.transfer(ethBought-_relayFee);
    }
}

