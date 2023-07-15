// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {AccessControl} from "openzeppelin/access/AccessControl.sol";
import {IUniswapV2Factory} from "uni-v2-core/interfaces/IUniswapV2Factory.sol";
import {IUniswapV2Router02} from "uni-v2-periphery/interfaces/IUniswapV2Router02.sol";

import {ITREASURY} from "@dera/Treasury.sol";
import {IERC20} from "openzeppelin/token/ERC20/IERC20.sol";

contract AMMv2Controller is AccessControl {
    address constant UNI_V2_FACTORY =
        0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f;
    address constant TREASURY_ADDRESS =
        0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f;
    address constant UNISWAP_V2_ROUTER_ADDRESS =
        0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;

    modifier onlyAdmin() {
        require(
            hasRole(DEFAULT_ADMIN_ROLE, msg.sender),
            "AMMv2Controller: not admin"
        );
        _;
    }

    constructor() {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin
    ) external onlyAdmin {
        // check that the pool exists
        if (
            IUniswapV2Factory(UNI_V2_FACTORY).getPair(tokenA, tokenB) ==
            address(0)
        ) revert("AMMv2Controller: pool does not exist");

        // check that the liquidity amount being added is not greater than the token allocation
        uint tokenAccountRatio = ITREASURY(TREASURY_ADDRESS).accountRatio(
            tokenA,
            address(this)
        );
        uint tokenBccountRatio = ITREASURY(TREASURY_ADDRESS).accountRatio(
            tokenB,
            address(this)
        );
        uint treasuryTokenABalance = IERC20(tokenA).balanceOf(TREASURY_ADDRESS);
        uint treasuryTokenBBalance = IERC20(tokenB).balanceOf(TREASURY_ADDRESS);

        uint maximumumTokenASpend = (tokenAccountRatio *
            treasuryTokenABalance) / 100;
        uint maximumumTokenBSpend = (tokenBccountRatio *
            treasuryTokenBBalance) / 100;

        if (amountADesired > maximumumTokenASpend)
            revert("AMMv2Controller: amountA exceeds allocation");
        if (amountBDesired > maximumumTokenBSpend)
            revert("AMMv2Controller: amountB exceeds allocation");

        // transfer the tokens to this contract

        IERC20(tokenA).transferFrom(
            TREASURY_ADDRESS,
            address(this),
            amountADesired
        );

        IERC20(tokenB).transferFrom(
            TREASURY_ADDRESS,
            address(this),
            amountBDesired
        );

        IUniswapV2Router02(UNISWAP_V2_ROUTER_ADDRESS).addLiquidity(
            tokenA,
            tokenB,
            amountADesired,
            amountBDesired,
            amountAMin,
            amountBMin,
            address(this),
            block.timestamp
        );
    }

    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin
    ) external onlyAdmin {
        IUniswapV2Router02(UNISWAP_V2_ROUTER_ADDRESS).removeLiquidity(
            tokenA,
            tokenB,
            liquidity,
            amountAMin,
            amountBMin,
            address(this),
            block.timestamp
        );
    }
}
