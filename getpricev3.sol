// SPDX-License-Identifier: MIT
pragma solidity ^0.7.6;

import "https://github.com/Uniswap/v3-core/blob/main/contracts/interfaces/IUniswapV3Pool.sol";
import "https://github.com/Uniswap/v3-core/blob/main/contracts/libraries/TickMath.sol";

//import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
interface IERC20 {
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (bool);
}
interface IERC20Metadata is IERC20 {
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function decimals() external view returns (uint8);
}




contract UniswapV3Oracle {
    //weth-usd³Ø×Ó
    address public uniswapV3PoolAddress = 0x7BeA39867e4169DBe237d55C8242a8f2fcDcc387;
    uint24 private twapDurationInSeconds;

    function getPrice() public view returns(uint32 price, uint32 decimalAdjFactor) {
        IUniswapV3Pool uniswapv3Pool = IUniswapV3Pool(uniswapV3PoolAddress);

        uint32[] memory secondAgos = new uint32[](2);
        secondAgos[0] = 10000;
        secondAgos[1] = 0;

        (int56[] memory tickCumulatives, ) = uniswapv3Pool.observe(secondAgos);

        int56 tickCumulativesDiff = tickCumulatives[1] - tickCumulatives[0];
        uint56 period = uint56(secondAgos[0]-secondAgos[1]);

        int56 timeWeightedAverageTick = (tickCumulativesDiff / -int56(period));

        uint8 decimalToken0 =  IERC20Metadata(uniswapv3Pool.token0()).decimals();
//      uint8 decimalToken1 =  IERC20Metadata(uniswapv3Pool.token1()).decimals();
        
        uint160 sqrtRatioX96 = TickMath.getSqrtRatioAtTick(int24(timeWeightedAverageTick));
        uint256 ratioX192 = uint256(sqrtRatioX96) * sqrtRatioX96;
        price = uint32((ratioX192 * 1e18) >> (96 * 2));
        decimalAdjFactor = uint32(10**(decimalToken0));        
    }


    function getSqrtTWAP(address uniswapV3Pool, uint32 twapInterval) external view returns (uint160 sqrtPriceX96) {
        IUniswapV3Pool pool = IUniswapV3Pool(uniswapV3Pool);
        (, , uint16 index, uint16 cardinality, , , ) = pool.slot0();
        (uint32 targetElementTime, , , bool initialized) = pool.observations((index + 1) % cardinality);
        if (!initialized) {
            (targetElementTime, , , ) = pool.observations(0);
        }
        uint32 delta = uint32(block.timestamp) - targetElementTime;
        if (delta == 0) {
            (sqrtPriceX96, , , , , , ) = pool.slot0();
        } else {
            if (delta < twapInterval) twapInterval = delta;
            uint32[] memory secondsAgos = new uint32[](2);
            secondsAgos[0] = twapInterval; // from (before)
            secondsAgos[1] = 0; // to (now)
            (int56[] memory tickCumulatives, ) = pool.observe(secondsAgos);
            // tick(imprecise as it's an integer) to price
            sqrtPriceX96 = TickMath.getSqrtRatioAtTick(
                int24((tickCumulatives[1] - tickCumulatives[0]) / int56(uint56(twapInterval)))
            );
        }
    }
}