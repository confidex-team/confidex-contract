// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./ConfidentialERC20.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

contract ConfidentialSoloPatty is ConfidentialERC20 {
    // Events
    event Deposited(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);

    // Structs
    struct ClaimInfo {
        bool hasClaimed;
        uint96 lastClaimTime;
    }

    // State variables
    address public immutable trustedSigner;
    mapping(bytes32 => ClaimInfo) private _claims;

    // Constructor
    constructor(address _trustedSigner) ConfidentialERC20() {
        trustedSigner = _trustedSigner;
    }

    /// @notice Users deposit confidential tokens into the contract
    function depositTokens(bytes calldata encryptedAmount) external {
        _mint(encryptedAmount);
        emit Deposited(msg.sender, 0); // Amount is encrypted, so we emit 0
    }

    /// @notice Users withdraw confidential tokens with a signed message from the TEE
    function withdrawTokensWithSignature(
        address user,
        bytes calldata encryptedAmount,
        bytes calldata signature
    ) external {
        // Verify TEE signature
        bytes32 leaf = keccak256(
            abi.encodePacked(user, address(this), encryptedAmount)
        );
        bytes32 ethHash = MessageHashUtils.toEthSignedMessageHash(leaf);
        address recovered = ECDSA.recover(ethHash, signature);
        require(recovered == trustedSigner, "Invalid TEE signature");

        // Check if already claimed
        ClaimInfo storage claim = _claims[leaf];
        require(!claim.hasClaimed, "Already claimed");
        claim.hasClaimed = true;
        claim.lastClaimTime = uint96(block.timestamp);

        // Transfer tokens using the inherited transfer function
        transfer(user, encryptedAmount);
        emit Withdrawn(user, 0); // Amount is encrypted, so we emit 0
    }
}
