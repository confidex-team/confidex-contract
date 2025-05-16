// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../ConfidentialERC20.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract Confidex is Ownable2Step, ReentrancyGuard {
    ConfidentialERC20 public confidentialToken;

    struct ClaimInfo {
        bool hasClaimed;
        uint96 lastClaimTime;
    }

    address public immutable trustedSigner;
    mapping(bytes32 => ClaimInfo) private _claims;

    event Deposited(address indexed user, address token, bytes encryptedAmount);
    event Withdrawn(address indexed user, address token, bytes encryptedAmount);

    error InvalidAmount();
    error InvalidSignature();
    error AlreadyClaimed();
    error InvalidToken();

    constructor(address _trustedSigner) Ownable(msg.sender) {
        if (_trustedSigner == address(0)) revert InvalidToken();
        trustedSigner = _trustedSigner;
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
        e.allow(transferAmount, trustedSigner);

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
        
        if (recovered != trustedSigner) revert InvalidSignature();

        ClaimInfo storage claim = _claims[leaf];
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
