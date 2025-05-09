// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@inco/lightning/src/Lib.sol";
import "@openzeppelin/contracts/access/Ownable2Step.sol";
import "./ConfidentialERC20.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

contract ConfiDex is ConfidentialERC20 {
    // Events
    event Deposited(address indexed user, address token, uint256 amount);
    event Withdrawn(address indexed user, address token, uint256 amount);

    // Structs
    struct ClaimInfo {
        bool hasClaimed;
        uint96 lastClaimTime;
    }

    // State variables
    address public immutable trustedSigner;
    mapping(bytes32 => ClaimInfo) private _claims;
    mapping(address => mapping(address => euint256)) internal balances; // token => user => balance

    // Constructor, Inherited from Ownable2Step to call inherited functions from Ownable
    constructor(address _trustedSigner) {
        trustedSigner = _trustedSigner;
    }

    modifier onlyOwner() override {
        require(msg.sender == owner(), "Not authorized");
        _;
    }

    /// @notice Users deposit confidential tokens into the contract (TEE listens off-chain)
    function depositTokens(
        address token,
        bytes calldata encryptedAmount
    ) external {
        euint256 amount = e.newEuint256(encryptedAmount, msg.sender);
        bytes memory encryptedZero = e.encrypt(0, msg.sender);
        euint256 zero = e.newEuint256(encryptedZero, msg.sender);
        ebool isValidAmount = e.gt(amount, zero);
        require(e.decrypt(isValidAmount), "Invalid amount");

        // Transfer the encrypted amount from the user to this contract
        e.allow(amount, address(this));
        balances[token][msg.sender] = e.add(
            balances[token][msg.sender],
            amount
        );

        emit Deposited(msg.sender, token, 0); // Amount is encrypted, so we emit 0
    }

    /// @notice Users withdraw confidential tokens with a signed message from the TEE
    function withdrawTokensWithSignature(
        address user,
        address token,
        bytes calldata encryptedAmount,
        bytes calldata signature
    ) external {
        euint256 amount = e.newEuint256(encryptedAmount, msg.sender);

        // Verify TEE signature
        bytes32 leaf = keccak256(
            abi.encodePacked(user, token, encryptedAmount)
        );
        bytes32 ethHash = MessageHashUtils.toEthSignedMessageHash(leaf);
        address recovered = ECDSA.recover(ethHash, signature);
        require(recovered == trustedSigner, "Invalid TEE signature");

        // Check if already claimed
        ClaimInfo storage claim = _claims[leaf];
        require(!claim.hasClaimed, "Already claimed");
        claim.hasClaimed = true;
        claim.lastClaimTime = uint96(block.timestamp);

        // Verify and transfer balance
        ebool canTransfer = e.ge(balances[token][user], amount);
        require(e.decrypt(canTransfer), "Insufficient balance");

        balances[token][user] = e.sub(balances[token][user], amount);
        e.allow(balances[token][user], address(this));
        e.allow(balances[token][user], user);

        emit Withdrawn(user, token, 0); // Amount is encrypted, so we emit 0
    }

    /// @notice Get encrypted balance of a user for a specific token
    function balanceOf(
        address token,
        address user
    ) public view returns (euint256) {
        return balances[token][user];
    }
}
