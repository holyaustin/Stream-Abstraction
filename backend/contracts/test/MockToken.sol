// SPDX-License-Identifier: MIT
pragma solidity ^0.7.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockToken is ERC20 {
    mapping(address => bool) minted;
    address owner;

    constructor(
        uint256 _initialSupply,
        string memory _name,
        string memory _symbol
    ) ERC20(_name, _symbol) {
        _mint(msg.sender, _initialSupply);
        owner = msg.sender;
    }

    function mint() public {
        require(!minted[msg.sender], "Already minted.");
        minted[msg.sender] = true;
        _mint(msg.sender, 100 ether);
    }

    function mintOwner(uint256 amount) public {
        require(msg.sender == owner, "Only owner can use this.");
        _mint(msg.sender, amount);
    }
}
