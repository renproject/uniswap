pragma solidity ^0.5.8;

import "./interfaces/IUniswapFactory.sol";
import "./UniswapExchangeAdapter.sol";
import "./UniswapReserveAdapter.sol";
import "darknode-sol/contracts/Shifter/Shifter.sol";
import "darknode-sol/contracts/Shifter/ShifterRegistry.sol";

/// @dev    Use this contract to deploy exchange, reserve adapters and the 
///         uniswap exchange contracts.
contract UniswapAdapterFactory {
    
    /// @notice The uniswap factory this contract would be communicating with. 
    IUniswapFactory factory;

    /// @notice The ren shifter registry this contract would be communicating 
    ///         with.
    ShifterRegistry registry;

    /// @notice A mapping of token addresses to exchange adapters.
    mapping (address=>UniswapExchangeAdapter) private exchangeAdapters;

    /// @notice A mapping of token addresses to reserve adapters.
    mapping (address=>UniswapReserveAdapter) private reserveAdapters;

    /// @notice initializes the factory and shifter registry contracts, this 
    ///         contract would be communicating with. 
    constructor(IUniswapFactory _factory, ShifterRegistry _registry) public {
        factory = _factory;
        registry = _registry;
    }
    
    /// @notice Create a Uniswap exchange, and Uniswap adapters for the given
    ///         given token.
    /// @param _token the token for which the exchange and exchange adapters 
    ///         should be deployed for.
    function createExchange(address _token) external 
        returns 
            (
                address exchange,
                UniswapExchangeAdapter exchangeAdapterAddress,
                UniswapReserveAdapter exchangeReserveAddress
            ) 
        {
        exchange = factory.createExchange(_token);
        Shifter shifter = Shifter(registry.getShifterByToken(_token));
        exchangeAdapterAddress = new UniswapExchangeAdapter(IUniswapExchange(exchange), shifter);
        exchangeAdapters[_token] = exchangeAdapterAddress;
        exchangeReserveAddress = new UniswapReserveAdapter(IUniswapReserve(exchange), shifter);
        reserveAdapters[_token] = exchangeReserveAddress;
    }

    /// @notice get the exchange adapter for a given token.
    /// @param _token the token for which the exchange adapter is needed for.
    function getExchangeAdapter(address _token) external view returns (UniswapExchangeAdapter) {
        return exchangeAdapters[_token];
    }

    /// @notice get the exchange adapter for a given token.
    /// @param _token the token for which the reserve adapter is needed for.
    function getReserveAdapter(address _token) external view returns (UniswapReserveAdapter) {
        return reserveAdapters[_token];
    }
}
