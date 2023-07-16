// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.19;

import "forge-std/Test.sol";

contract BaseTest is Test {
    function name(address token) public view returns (string memory tokenName) {
        (, bytes memory data) = token.staticcall(
            abi.encodeWithSignature("name()")
        );

        (tokenName) = abi.decode(data, (string));
    }
}
