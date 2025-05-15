pragma solidity ^0.8.24;

import "./ConfidentialERC20.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract Confidex is ConfidentialERC20 {
    ConfidentialERC20 public confidentialToken;

    struct ClaimInfo {
        bool hasClaimed;
        uint96 lastClaimTime;
    }

    address public immutable trustedSigner;
    mapping(bytes32 => ClaimInfo) private _claims;

    event Deposited(address indexed user, address token, uint256 amount);
    event Withdrawn(address indexed user, address token, uint256 amount);

    constructor(
        address _trustedSigner,
        string memory name,
        string memory symbol
    ) ConfidentialERC20(name, symbol) {
        trustedSigner = _trustedSigner;
    }

    modifier onlyOwner() override {
        require(msg.sender == owner(), "Not authorized");
        _;
    }

    /// @notice Users deposit tokens into the contract (TEE listens off-chain)
    function depositTokenCheck(
        address token,
        euint256 encryptedAmount
    ) external {
        // Create encrypted zero for comparison
        euint256 encryptedZero = e.asEuint256(0);
        ebool isValidAmount = e.gt(encryptedAmount, encryptedZero);

        // Request decryption of the boolean
        // The callback will be this.handleDecryption
        // We pass the token and amount as callback data
        e.requestDecryption(
            isValidAmount,
            this.depositToken.selector,
            abi.encode(token, encryptedAmount)
        );
    }

    // Callback function that will be called after decryption
    function depositToken(
        uint256 requestId,
        bool isValidAmount,
        bytes memory callbackData
    ) external {
        require(isValidAmount, "Amount must be greater than zero");

        // Decode the callback data to get our original parameters
        (address token, euint256 encryptedAmount) = abi.decode(
            callbackData,
            (address, euint256)
        );

        // Now we can safely transfer
        ConfidentialERC20(token).transferFrom(
            msg.sender,
            address(this),
            encryptedAmount
        );

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
