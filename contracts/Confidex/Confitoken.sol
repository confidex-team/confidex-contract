// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../ConfidentialERC20.sol";

/**
 * @title SimpleToken
 * @dev A simple ERC20 token with burnable and ownable functionality using OpenZeppelin contracts
 */
contract SimpleToken is ConfidentialERC20 {
    /**
     * @dev Constructor that gives the msg.sender all of existing tokens.
     * @param initialSupply The initial token supply to mint to the contract creator
     * @param name The name of the token
     * @param symbol The symbol of the token
     */
    constructor(
        uint256 initialSupply,
        string memory name,
        string memory symbol
    ) ConfidentialERC20(name, symbol) {
        mint(initialSupply);
    }

    /**
     * @dev Function to mint tokens.
     * @param to The address that will receive the minted tokens
     * @param amount The amount of tokens to mint
     */
    function mint(address to, uint256 amount) public onlyOwner {
        mint(to, amount);
    }
}
