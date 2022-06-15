// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract MockERC721 is ERC721 {
    using Counters for Counters.Counter;

    Counters.Counter internal _current;
    
    constructor() ERC721("ERC721 Mock", "MOCK721") {}

    function mint(address to, uint256 quantity) public {
        for (uint256 i = 0; i < quantity; i++) {
            _mint(to, _current.current());
            _current.increment();
        }
    }
}