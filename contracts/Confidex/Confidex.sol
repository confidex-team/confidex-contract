pragma solidity ^0.8.24;

import "../ConfidentialERC20.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract Confidex is Ownable2Step {
    ConfidentialERC20 public confidentialToken;

    struct ClaimInfo {
        bool hasClaimed;
        uint96 lastClaimTime;
    }

    address public immutable trustedSigner;
    mapping(bytes32 => ClaimInfo) private _claims;

    event Deposited(address indexed user, address token, uint256 amount);
    event Withdrawn(address indexed user, address token, uint256 amount);

    constructor(address _trustedSigner) Ownable(msg.sender) {
        trustedSigner = _trustedSigner;
    }

    /// @notice Users deposit tokens into the contract (TEE listens off-chain)

    // Modified callback function with direct parameters
    function depositToken(address token, euint256 encryptedAmount) external {
        euint256 encryptedZero = e.asEuint256(0);
        ebool isValidAmount = e.gt(encryptedAmount, encryptedZero);

        e.allow(isValidAmount, address(this));

        // require(isValidAmount, "Amount must be greater than zero");

        // Now we can use the decoded parameters
        ConfidentialERC20(token).transferFrom(
            msg.sender,
            address(this),
            encryptedAmount
        );
        e.allow(encryptedAmount, address(this));
        e.allow(encryptedAmount, msg.sender);
        e.allow(encryptedAmount, trustedSigner);

        emit Deposited(msg.sender, token, 0);
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
        SafeERC20.safeTransfer(IERC20(token), user, amount);

        emit Withdrawn(user, token, amount);
    }
}
