// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { ConfidentialERC20 } from "../ConfidentialERC20.sol";
import { ECDSA } from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import { MessageHashUtils } from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { Ownable2Step, Ownable } from "@openzeppelin/contracts/access/Ownable2Step.sol";
import { e, euint256, ebool } from "@inco/lightning/src/Lib.sol";

contract Confidex is Ownable2Step, ReentrancyGuard {
    ConfidentialERC20 public confidentialToken;

    struct ClaimInfo {
        bool hasClaimed;
        uint96 lastClaimTime;
    }

    address public immutable TRUSTED_SIGNER;
    mapping(bytes32 => ClaimInfo) private claims;

    event Deposited(address indexed user, address token, bytes encryptedAmount);
    event Withdrawn(address indexed user, address token, bytes encryptedAmount);

    error InvalidAmount();
    error InvalidSignature();
    error AlreadyClaimed();
    error InvalidToken();

    constructor(address _trustedSigner) Ownable(msg.sender) {
        if (_trustedSigner == address(0)) revert InvalidToken();
        TRUSTED_SIGNER = _trustedSigner;
    }

    /// @notice Users deposit tokens into the contract (TEE listens off-chain)
    function depositToken(address token, bytes calldata encryptedAmount) external nonReentrant {
        if (token == address(0)) revert InvalidToken();
        
        euint256 encryptedZero = e.asEuint256(0);
        euint256 amount = e.newEuint256(encryptedAmount, msg.sender);
        ebool isValidAmount = e.gt(amount, encryptedZero);
        e.allow(isValidAmount, address(this));

        // Use e.select to handle the entire flow
        euint256 transferAmount = e.select(isValidAmount, amount, encryptedZero);
        e.allow(transferAmount, address(this));
        e.allow(transferAmount, msg.sender);
        e.allow(transferAmount, TRUSTED_SIGNER);

        // If amount is zero, revert
        ebool isZero = e.eq(transferAmount, encryptedZero);
        e.allow(isZero, address(this));
        e.select(isZero, e.asEuint256(0), amount);

        ConfidentialERC20(token).transferFrom(
            msg.sender,
            address(this),
            encryptedAmount
        );

        emit Deposited(msg.sender, token, encryptedAmount);
    }

    /// @notice Users withdraw funds with a signed message from the TEE
    function withdrawTokensWithSignature(
        address user,
        address token,
        bytes calldata encryptedAmount,
        bytes calldata signature
    ) external nonReentrant {
        if (token == address(0)) revert InvalidToken();
        if (user == address(0)) revert InvalidToken();

        bytes32 leaf = keccak256(abi.encodePacked(user, token, encryptedAmount));
        bytes32 ethHash = MessageHashUtils.toEthSignedMessageHash(leaf);
        address recovered = ECDSA.recover(ethHash, signature);
        
        if (recovered != TRUSTED_SIGNER) revert InvalidSignature();

        ClaimInfo storage claim = claims[leaf];
        if (claim.hasClaimed) revert AlreadyClaimed();

        claim.hasClaimed = true;
        claim.lastClaimTime = uint96(block.timestamp);

        ConfidentialERC20(token).transfer(user, encryptedAmount);

        emit Withdrawn(user, token, encryptedAmount);
    }

    /// @notice Emergency function to recover stuck tokens
    function recoverTokens(address token, address to) external onlyOwner {
        if (to == address(0)) revert InvalidToken();
        euint256 balance = ConfidentialERC20(token).balanceOf(address(this));
        ConfidentialERC20(token).transferFrom(address(this), to, balance);
    }
}
