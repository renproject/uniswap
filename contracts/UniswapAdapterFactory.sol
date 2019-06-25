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

    /// @notice Initialize the factory and shifter registry contracts, this 
    ///         contract would be communicating with and create exchannges 
    ///         for all the registered shifted tokens. 
    constructor(IUniswapFactory _factory, ShifterRegistry _registry) public {
        factory = _factory;
        registry = _registry;

        // create exchanges for all the registered shifted tokens.
        address[] memory shiftedTokens = _registry.getShiftedTokens(address(0), 0);
        for (uint64 i = 0; i < shiftedTokens.length; i++) {
            createExchange(shiftedTokens[i]);
        }
    }
    
    /// @notice Create a Uniswap exchange, and Uniswap adapters for the given
    ///         given token.
    /// @param _token The token for which the exchange and exchange adapters 
    ///         should be deployed for.
    function createExchange(address _token) public 
        returns 
            (
                address exchange,
                UniswapExchangeAdapter exchangeAdapterAddress,
                UniswapReserveAdapter exchangeReserveAddress
            ) 
        {
        // Check whether an exchange already exists for the given token, if it 
        // does not create one.
        exchange = factory.getExchange(_token);
        if (exchange == address(0x0)) {
            exchange = factory.createExchange(_token);
        }

        // Check whether the exchange adapters already exist.
        require(exchangeAdapters[_token] == UniswapExchangeAdapter(0x0), "exchange adapter already exist");
        Shifter shifter = Shifter(registry.getShifterByToken(_token));

        // Deploy uniswap exchange adapter and store it.
        exchangeAdapterAddress = new UniswapExchangeAdapter(IUniswapExchange(exchange), shifter);
        exchangeAdapters[_token] = exchangeAdapterAddress;

        // Deploy uniswap reserve adapter and store it.
        exchangeReserveAddress = new UniswapReserveAdapter(IUniswapReserve(exchange), shifter);
        reserveAdapters[_token] = exchangeReserveAddress;
    }

    /// @notice Get the exchange adapter for a given token.
    /// @param _token the token for which the exchange adapter is needed for.
    function getExchangeAdapter(address _token) external view returns (UniswapExchangeAdapter) {
        return exchangeAdapters[_token];
    }

    /// @notice Get the exchange adapter for a given token.
    /// @param _token the token for which the reserve adapter is needed for.
    function getReserveAdapter(address _token) external view returns (UniswapReserveAdapter) {
        return reserveAdapters[_token];
    }
}
