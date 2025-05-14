pragma solidity ^0.8.24;

import "./ConfidentialERC20.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

contract Confidex is ConfidentialERC20 {
    ConfidentialERC20 public confidentialToken;

    struct ClaimInfo {
        bool hasClaimed;
        uint96 lastClaimTime;
    }

    address public immutable owner;
    address public immutable trustedSigner;
    mapping(bytes32 => ClaimInfo) private _claims;

    event Deposited(address indexed user, address token, uint256 amount);
    event Withdrawn(address indexed user, address token, uint256 amount);

    constructor(address _trustedSigner) {
        owner = msg.sender;
        trustedSigner = _trustedSigner;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Not authorized");
        _;
    }

    /// @notice Users deposit tokens into the contract (TEE listens off-chain)
    function depositTokens(
        address token,
        bytes calldata encryptedAmount
    ) external {
        // Create encrypted zero for comparison
        bytes memory encryptedZero = e.encrypt(0, msg.sender);
        euint256 zero = e.newEuint256(encryptedZero, msg.sender);

        // Check if amount is greater than zero
        ebool isValidAmount = e.gt(encryptedAmount, zero);
        require(e.decrypt(isValidAmount), "Invalid amount");

        // Transfer the encrypted amount from user to contract
        ConfidentialERC20(token).transfer(address(this), encryptedAmount);

        emit Deposited(msg.sender, token, 0); // Amount is encrypted, so we emit 0
    }

    /// @notice Users withdraw funds with a signed message from the TEE
    function withdrawTokensWithSignature(
        address user,
        address token,
        uint256 amount,
        bytes calldata signature
    ) external {
        bytes32 leaf = keccak256(abi.encodePacked(user, token, amount));
        bytes32 ethHash = MessageHashUtils.toEthSignedMessageHash(leaf);
        address recovered = ECDSA.recover(ethHash, signature);
        require(recovered == trustedSigner, "Invalid TEE signature");

        ClaimInfo storage claim = _claims[leaf];
        require(!claim.hasClaimed, "Already claimed");

        claim.hasClaimed = true;
        claim.lastClaimTime = uint96(block.timestamp);

        // ✅ Use safeTransfer
        IERC20(token).safeTransfer(user, amount);

        emit Withdrawn(user, token, amount);
    }
}
