// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {AMMv2Controller, IAMMv2Controller} from "@dera/controllers/AMMv2Controller.sol";
import {Treasury} from "@dera/Treasury.sol";
import {IERC20} from "openzeppelin/token/ERC20/IERC20.sol";
import {IUniswapV2Factory} from "uni-v2-core/interfaces/IUniswapV2Factory.sol";
import {IUniswapV2Pair} from "uni-v2-core/interfaces/IUniswapV2Pair.sol";
import {BaseTest} from "./BaseTest.sol";

contract TestAMMv2Controller is BaseTest {
    AMMv2Controller ammUniController;
    Treasury treasury;
    address WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address UNI_V2_FACTORY = 0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f;
    address constant UNISWAP_V2_ROUTER_ADDRESS =
        0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;

    address ADMIN_EOA = makeAddr("admin");

    function setUp() external {
        string memory RPC_URL = "http://127.0.0.1:8545";

        vm.createSelectFork(RPC_URL);

        treasury = new Treasury();
        ammUniController = new AMMv2Controller(address(treasury));

        deal(USDC, ADMIN_EOA, 100 ether);
    }

    function testDepositToTreasury() external {
        vm.startPrank(ADMIN_EOA);
        uint depositAmount = 10 ether;
        uint treasuryBalanceBeforeDeposit = IERC20(USDC).balanceOf(
            address(treasury)
        );
        IERC20(USDC).transfer(address(treasury), depositAmount);

        uint treasuryBalanceAfterDeposit = IERC20(USDC).balanceOf(
            address(treasury)
        );

        assertEq(
            treasuryBalanceAfterDeposit - treasuryBalanceBeforeDeposit,
            depositAmount,
            "Treasury balance should be increased by deposit amount"
        );

        vm.stopPrank();
    }

    function testOnlyAdmin() external {
        address randomAddress = makeAddr("random");
        assertNotEq(
            randomAddress,
            address(treasury),
            "Random address generated is same as treasury address, will raise a false positive"
        );

        vm.prank(randomAddress);
        vm.expectRevert(bytes("Treasury: not admin"));
        treasury.setAccountRatio(WETH, address(ammUniController), 10);
    }

    function testSetAccountRatio() external {
        treasury.setAccountRatio(WETH, address(ammUniController), 10);
        uint256 ratio = treasury.accountRatio(WETH, address(ammUniController));

        assertEq(ratio, 10, "ratio should be 10");
    }

    function testApproveController() external {
        treasury.approveController(WETH, address(ammUniController), 1 ether);
        uint256 allowance = IERC20(WETH).allowance(
            address(treasury),
            address(ammUniController)
        );

        assertEq(allowance, 1 ether, "allowance should be 1 ether");
    }

    function testApproveSpender() external {
        ammUniController.approveSpender(
            WETH,
            UNISWAP_V2_ROUTER_ADDRESS,
            1 ether
        );
        uint256 allowance = IERC20(WETH).allowance(
            address(ammUniController),
            UNISWAP_V2_ROUTER_ADDRESS
        );

        assertEq(allowance, 1 ether, "allowance should be 1 ether");
    }

    function testAddAndRemoveLiquidity() external {
        vm.label(WETH, name(WETH));
        vm.label(USDC, name(USDC));
        vm.label(address(treasury), "TREASURY");
        vm.label(UNI_V2_FACTORY, "UNI_V2_FACTORY");
        vm.label(UNISWAP_V2_ROUTER_ADDRESS, "UNISWAP_V2_ROUTER_ADDRESS");

        treasury.setAccountRatio(WETH, address(ammUniController), 10);
        treasury.setAccountRatio(USDC, address(ammUniController), 10);

        deal(WETH, address(treasury), 100 ether);
        deal(USDC, address(treasury), 100 ether);

        treasury.approveController(WETH, address(ammUniController), 1 ether);
        treasury.approveController(USDC, address(ammUniController), 1 ether);

        ammUniController.approveSpender(
            WETH,
            UNISWAP_V2_ROUTER_ADDRESS,
            1 ether
        );
        ammUniController.approveSpender(
            USDC,
            UNISWAP_V2_ROUTER_ADDRESS,
            1 ether
        );

        address tokenA = WETH;
        address tokenB = USDC;
        uint amountADesired = 1 ether;
        uint amountBDesired = 1 ether;
        uint amountAMin = 0;
        uint amountBMin = 0;

        IUniswapV2Factory factory = IUniswapV2Factory(UNI_V2_FACTORY);
        address pair = factory.getPair(tokenA, tokenB);
        vm.label(pair, name(pair));

        (uint reserveABefore, uint reserveBBefore, ) = IUniswapV2Pair(pair)
            .getReserves();

        uint lpTokensMinted = ammUniController.addLiquidity(
            tokenA,
            tokenB,
            amountADesired,
            amountBDesired,
            amountAMin,
            amountBMin
        );

        (uint reserveAAfter, uint reserveBAfter, ) = IUniswapV2Pair(pair)
            .getReserves();

        assertGt(
            reserveAAfter,
            reserveABefore,
            "reserveAAfter > reserveABefore"
        );

        assertGt(
            reserveBAfter,
            reserveBBefore,
            "reserveBAfter > reserveBBefore"
        );

        this.removeLiquidity(lpTokensMinted);
    }

    function removeLiquidity(uint lpTokensMinted) external {
        address tokenA = WETH;
        address tokenB = USDC;
        uint amountAMin = 0;
        uint amountBMin = 0;

        vm.label(WETH, name(WETH));
        vm.label(USDC, name(USDC));
        vm.label(address(treasury), "TREASURY");
        vm.label(UNI_V2_FACTORY, "UNI_V2_FACTORY");
        vm.label(UNISWAP_V2_ROUTER_ADDRESS, "UNISWAP_V2_ROUTER_ADDRESS");

        IUniswapV2Factory factory = IUniswapV2Factory(UNI_V2_FACTORY);
        address pair = factory.getPair(tokenA, tokenB);
        vm.label(pair, "WETH-USDC PAIR");

        (uint reserveABefore, uint reserveBBefore, ) = IUniswapV2Pair(pair)
            .getReserves();

        ammUniController.approveSpender(
            pair,
            UNISWAP_V2_ROUTER_ADDRESS,
            ~uint256(0)
        );

        ammUniController.removeLiquidity(
            tokenA,
            tokenB,
            lpTokensMinted,
            amountAMin,
            amountBMin
        );

        (uint reserveAAfter, uint reserveBAfter, ) = IUniswapV2Pair(pair)
            .getReserves();

        assertLt(
            reserveAAfter,
            reserveABefore,
            "reserveAAfter < reserveABefore"
        );

        assertLt(
            reserveBAfter,
            reserveBBefore,
            "reserveBAfter < reserveBBefore"
        );
    }
}
