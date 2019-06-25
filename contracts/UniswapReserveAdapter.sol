pragma solidity ^0.5.8;

import "./interfaces/IUniswapReserve.sol";
import "darknode-sol/contracts/Shifter/Shifter.sol";
import "openzeppelin-solidity/contracts/token/ERC20/IERC20.sol";

/// @notice funds should NEVER be transferred directly to this contract, as they 
///         would be lost forever.
/// @dev    Do not deploy this contract directly, allow the 
///         UniswapAdapterFactory to do the contract deployments.
contract UniswapReserveAdapter {

    /// @notice This contract is associated with a single token, the primary 
    ///         token of this contract.
    IERC20 token;

    /// @notice The uniswap reserve this contract would be communicating with.
    IUniswapReserve public reserve;  

    /// @notice The ren shifter this contract would be communicating with.
    Shifter public shifter;  

    /// @notice Initialize the reserve and shifter contracts, this contract 
    ///         would be communicating with. 
    constructor(IUniswapReserve _reserve, Shifter _shifter) public {
        reserve = _reserve;
        shifter = _shifter;
        token = IERC20(shifter.token());
    }

    /// @notice Allow only the reserve contract to send eth to this contract, 
    ///         this protects users from sending ether to this contract by 
    ///         mistake.
    function () external payable {
        require(msg.sender == address(reserve), "only allow reserve to transfer eth into this contract");
    }

    /// @notice Allow the liquidity provider to provide liquidity to a uniswap 
    ///         reserve.
    /// @param _minLiquidity Minimum number of UNI sender will mint if total UNI
    ///         supply is greater than 0.
    /// @param _refundAddress is the specific blockchain address to refund the 
    ///         funds to on the expiry of this trade.
    /// @param _deadline The unix timestamp until which this transaction is 
    ///         valid till.
    /// @param _amount The amount of the primary token the trader is willing to 
    ///         spend.
    /// @param _nHash This is used by the ren shifter contract to guarentee the 
    ///         uniqueness of this request.
    /// @param _sig The signature returned by RenVM.
    function addLiquidity(
        uint256 _minLiquidity, bytes calldata _refundAddress, uint256 _deadline,
        uint256 _amount, bytes32 _nHash, bytes calldata _sig
        ) 
            external 
            payable 
            returns (uint256  uniMinted) 
        {
        // Calculate payload hash and shift in the required tokens.
        bytes32 pHash = keccak256(abi.encode(_minLiquidity, _refundAddress, _deadline));
        uint256 amount = shifter.shiftIn(pHash, _amount, _nHash, _sig);

        // If this deadline passes ERC20Shifted tokens are shifted in and
        // shifted out immediately.
        if (now > _deadline) {
            shifter.shiftOut(_refundAddress, amount);
            return 0;
        }

        // Add liquidity to the uniswap reserve.
        token.approve(address(reserve), _amount);
        uniMinted = reserve.addLiquidity.value(msg.value)(_minLiquidity, amount, _deadline);

        // Shift out any remaining tokens to the refund address on the native 
        // blockchain.
        uint256 balance = token.balanceOf(address(this));
        if ( balance > 0 ) {
            shifter.shiftOut(_refundAddress, balance);
        }

        // Transfer minted uni to msg.sender, these would be required to 
        // remove liquidity.
        reserve.transfer(msg.sender, uniMinted);
        return uniMinted;
    }

    /// @notice Allow the liquidity provider to remove liquidity from a uniswap 
    ///         reserve.
    /// @param _uniAmount Amount of UNI the liquidity provider wants to burn.
    /// @param _minEth Minimum amount of ether the liquidity provider is 
    ///         willing to withdraw.
    /// @param _minTokens Minimum amount of this.token the liquidity 
    ///         provider is willing to withdraw.
    /// @param _to Native blockchain address to receive the funds to.
    /// @param _deadline The unix timestamp until which this transaction is 
    ///         valid till.
    function removeLiquidity(
            uint256 _uniAmount, uint256 _minEth, uint256 _minTokens,
            bytes calldata _to, uint256 _deadline
        ) 
            external 
            payable 
            returns (uint256  eth, uint256 tokens)
        {
        // Receive the uni that is meant to be burned and remove the liquidity 
        // from the reserve.
        require(reserve.transferFrom(msg.sender, address(this), _uniAmount), "uni allowance not provided");
        (eth, tokens) = reserve.removeLiquidity(_uniAmount, _minEth, _minTokens, _deadline);

        // Transfer the funds to the user.
        tokens = shifter.shiftOut(_to, tokens);
        msg.sender.transfer(eth);
    }
}