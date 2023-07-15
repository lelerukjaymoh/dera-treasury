// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {AccessControl} from "openzeppelin/access/AccessControl.sol";
import {IERC20} from "openzeppelin/token/ERC20/IERC20.sol";

interface ITREASURY {
    function accountRatio(
        address token,
        address account
    ) external view returns (uint256);
}

contract Treasury is AccessControl {
    mapping(address => mapping(address => uint256)) public accountRatio;

    // Events
    event InvestmentDistributed(address token, uint amount);

    modifier onlyAdmin() {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "Treasury: not admin");
        _;
    }

    constructor() {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    function setAccountRatio(
        address _token,
        address _account,
        uint256 _ratio
    ) external onlyAdmin {
        accountRatio[_token][_account] = _ratio;
    }

    function approveController(
        address token,
        address controller,
        uint amount
    ) external onlyAdmin {
        IERC20(token).approve(controller, amount);
    }
}
