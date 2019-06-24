pragma solidity ^0.5.8;

import "./interfaces/IUniswapReserve.sol";
import "darknode-sol/contracts/Shifter/Shifter.sol";
import "openzeppelin-solidity/contracts/token/ERC20/IERC20.sol";

/// @notice funds should NEVER be transferred directly to this contract, as they 
///         would be lost forever.
/// @dev    this contract should not be deployed directly, allow the 
///         UniswapAdapterFactory to do the contract deployments.
contract UniswapReserveAdapter {

    /// @notice this contract is associated with a single token.
    IERC20 token;

    /// @notice the uniswap reserve this contract would be communicating with.
    IUniswapReserve public reserve;  

    /// @notice the ren shifter this contract would be communicating with.
    Shifter public shifter;  

    /// @notice initializes the reserve and shifter contracts, this contract 
    ///         would be communicating with. 
    constructor(IUniswapReserve _reserve, Shifter _shifter) public {
        reserve = _reserve;
        shifter = _shifter;
        token = IERC20(shifter.token());
    }

    /// @notice this function only allows the reserve contract to send eth to 
    ///         this contract, this protects users from sending ether to this 
    ///         contract by mistake.
    function () external payable {
        require(msg.sender == address(reserve), "only allow reserve to transfer eth into this contract");
    }

    /// @notice this function allows the liquidity provider to provide liquidity
    ///         to a uniswap reserve.
    /// @param _amount the amount of the primary token the trader is willing to 
    ///         to spend.
    /// @param _nHash this is used by the ren shifter contract to guarentee the 
    ///         uniqueness of this request.
    /// @param _sig is the signature returned by RenVM.
    /// @param _minLiquidity Minimum number of UNI sender will mint if total UNI
    ///         supply is greater than 0.
    /// @param _refundAddress is the specific blockchain address to refund the 
    ///         funds to on the expiry of this trade.
    /// @param _deadline is the unix timestamp until which this transaction is 
    ///         valid till.
    function addLiquidity(
        uint256 _amount, bytes32 _nHash, bytes calldata _sig,
        uint256 _minLiquidity, bytes calldata _refundAddress, uint256 _deadline
        ) 
            external 
            payable 
            returns (uint256  uniMinted) 
        {
        bytes32 pHash = keccak256(abi.encode(_minLiquidity, _refundAddress, _deadline));
        uint256 amount = shifter.shiftIn(_amount, _nHash, _sig, pHash);

        if (now > _deadline) {
            shifter.shiftOut(_refundAddress, amount);
            return 0;
        }

        token.approve(address(reserve), _amount);
        uniMinted = reserve.addLiquidity.value(msg.value)(_minLiquidity, amount, _deadline);

        uint256 balance = token.balanceOf(address(this));
        if ( balance > 0 ) {
            shifter.shiftOut(_refundAddress, balance);
        }
        reserve.transfer(msg.sender, uniMinted);
        return uniMinted;
    }

    /// @notice this function allows the liquidity provider to remove liquidity
    ///         from a uniswap reserve.
    /// @param _uniAmount Amount of UNI the liquidity provider wants to burn.
    /// @param _minEth the minimum amount of ether the liquidity provider is 
    ///         willing to withdraw.
    /// @param _minTokens the minimum amount of this.token the liquidity 
    ///         provider is willing to withdraw.
    /// @param _to is the specific blockchain address to receive the funds to.
    /// @param _deadline is the unix timestamp until which this transaction is 
    ///         valid till.
    function removeLiquidity(
            uint256 _uniAmount, uint256 _minEth, uint256 _minTokens,
            bytes calldata _to, uint256 _deadline
        ) 
            external 
            payable 
            returns (uint256  eth, uint256 tokens)
        {
        require(reserve.transferFrom(msg.sender, address(this), _uniAmount), "uni allowance not provided");
        (eth, tokens) = reserve.removeLiquidity(_uniAmount, _minEth, _minTokens, _deadline);
        tokens = shifter.shiftOut(_to, tokens);
        msg.sender.transfer(eth);
    }
}