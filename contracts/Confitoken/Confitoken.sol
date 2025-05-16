// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { ConfidentialERC20 } from "../ConfidentialERC20.sol";

/**
 * @title SimpleToken
 * @dev A simple ERC20 token with burnable and ownable functionality using OpenZeppelin contracts
 */
contract ConfiToken is ConfidentialERC20 {
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
     * @param amount The amount of tokens to mint
     */
    function mint(uint256 amount) public override onlyOwner {
        super.mint(amount);
    }
}
