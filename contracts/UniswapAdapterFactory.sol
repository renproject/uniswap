pragma solidity ^0.5.8;

import "./UniswapExchangeAdapter.sol";
import "./UniswapReserveAdapter.sol";
import "darknode-sol/contracts/Shifter/Shifter.sol";
import "darknode-sol/contracts/Shifter/ShifterRegistry.sol";

interface IUniswapFactory {
    function createExchange(address token) external returns (address);
    function getExchange(address token) external view returns (address);
}

contract UniswapAdapterFactory {
    IUniswapFactory factory;
    ShifterRegistry registry;

    mapping (address=>UniswapExchangeAdapter) exchangeAdapters;
    mapping (address=>UniswapReserveAdapter) reserveAdapters;

    constructor(IUniswapFactory _factory, ShifterRegistry _registry) public {
        factory = _factory;
        registry = _registry;
    }

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

    function getExchangeAdapter(address _token) external view returns (UniswapExchangeAdapter) {
        return exchangeAdapters[_token];
    }

    function getReserveAdapter(address _token) external view returns (UniswapReserveAdapter) {
        return reserveAdapters[_token];
    }
}
