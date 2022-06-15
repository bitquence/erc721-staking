// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockERC20 is ERC20 {
    constructor() ERC20("ERC20 Mock", "MOCK20") {}

    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }
}