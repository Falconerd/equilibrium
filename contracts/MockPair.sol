// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import "./ERC20.sol";

contract MockPair is ERC20 {
    address public immutable token0;
    address public immutable token1;
    bool public immutable is_stable;
    uint public reserve0;
    uint public reserve1;

    event PairCreated(address t0, address t1, string n0, string n1);

    constructor(address _token0, address _token1, bool _is_stable) ERC20(
        string.concat(_is_stable ? "s" : "v", "AMM-", ERC20(_token0).symbol(), "/", ERC20(_token1).symbol()),
        string.concat(_is_stable ? "s" : "v", "AMM-", ERC20(_token0).symbol(), "/", ERC20(_token1).symbol())
    ) {
        token0 = _token0;
        token1 = _token1;
        is_stable = _is_stable;
        _mint(msg.sender, 1e22);

        emit PairCreated(token0, token1, ERC20(token0).symbol(), ERC20(token1).symbol());
    }

    function setMetadata(uint _r0, uint _r1) external {
        reserve0 = _r0;
        reserve1 = _r1;
    }

    function getAmountOut(uint _amountIn, address _tokenIn) external view returns (uint) {
        if (is_stable) {
            uint xy = _k(reserve0, reserve1);
            uint r0 = reserve0 * 1e18 / ERC20(token0).decimals();
            uint r1 = reserve1 * 1e18 / ERC20(token1).decimals();
            (uint rA, uint rB) = _tokenIn == token0 ? (r0, r1) : (r1, r0);
            _amountIn = _tokenIn == token0 ? _amountIn * 1e18 / ERC20(token0).decimals() : _amountIn * 1e18 / ERC20(token1).decimals();
            uint y = rB - _get_y(_amountIn+rA, xy, rB);
            return y * (_tokenIn == token0 ? ERC20(token1).decimals() : ERC20(token0).decimals()) / 1e18;
        } else {
            (uint rA, uint rB) = _tokenIn == token0 ? (reserve0, reserve1) : (reserve1, reserve0);
            return _amountIn * rB / (rA + _amountIn);
        }
    }

    function _k(uint x, uint y) internal view returns (uint) {
        if (is_stable) {
            uint _x = x * 1e18 / ERC20(token0).decimals();
            uint _y = y * 1e18 / ERC20(token1).decimals();
            uint _a = (_x * _y) / 1e18;
            uint _b = ((_x * _x) / 1e18 + (_y * _y) / 1e18);
            return _a * _b / 1e18;
        } else {
            return reserve0 * reserve1;
        }
    }

    function _get_y(uint x0, uint xy, uint y) internal pure returns (uint) {
        for (uint i = 0; i < 255; i++) {
            uint y_prev = y;
            uint k = _f(x0, y);
            if (k < xy) {
                uint dy = (xy - k)*1e18/_d(x0, y);
                y = y + dy;
            } else {
                uint dy = (k - xy)*1e18/_d(x0, y);
                y = y - dy;
            }
            if (y > y_prev) {
                if (y - y_prev <= 1) {
                    return y;
                }
            } else {
                if (y_prev - y <= 1) {
                    return y;
                }
            }
        }
        return y;
    }

    function _f(uint x0, uint y) internal pure returns (uint) {
        return x0*(y*y/1e18*y/1e18)/1e18+(x0*x0/1e18*x0/1e18)*y/1e18;
    }

    function _d(uint x0, uint y) internal pure returns (uint) {
        return 3*x0*(y*y/1e18)/1e18+(x0*x0/1e18*x0/1e18);
    }
}

