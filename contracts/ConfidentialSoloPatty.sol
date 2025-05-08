// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@inco/lightning/src/Lib.sol";
import "@openzeppelin/contracts/access/Ownable2Step.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

contract ConfidentialSoloPatty is Ownable2Step {
    // Events
    event Deposited(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event UserBalanceDecrypted(address indexed user, uint256 decryptedAmount);

    // Structs
    struct ClaimInfo {
        bool hasClaimed;
        uint96 lastClaimTime;
    }

    // State variables
    address public immutable trustedSigner;
    mapping(bytes32 => ClaimInfo) private _claims;
    mapping(address => euint256) internal balances;
    mapping(uint256 => address) internal requestIdToUserAddress;

    // Constructor
    constructor(address _trustedSigner) Ownable(msg.sender) {
        trustedSigner = _trustedSigner;
    }

    // Modifiers
    modifier onlyOwner() {
        require(msg.sender == owner(), "Not authorized");
        _;
    }

    /// @notice Users deposit confidential tokens into the contract
    function depositTokens(bytes calldata encryptedAmount) external {
        euint256 amount = e.newEuint256(encryptedAmount, msg.sender);
        balances[msg.sender] = e.add(balances[msg.sender], amount);
        e.allow(balances[msg.sender], address(this));
        e.allow(balances[msg.sender], msg.sender);
        emit Deposited(msg.sender, 0); // Amount is encrypted, so we emit 0
    }

    /// @notice Users withdraw confidential tokens with a signed message from the TEE
    function withdrawTokensWithSignature(
        address user,
        bytes calldata encryptedAmount,
        bytes calldata signature
    ) external {
        euint256 amount = e.newEuint256(encryptedAmount, msg.sender);

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

        // Verify and transfer balance
        ebool canTransfer = e.ge(balances[user], amount);
        require(e.decrypt(canTransfer), "Insufficient balance");

        balances[user] = e.sub(balances[user], amount);
        e.allow(balances[user], address(this));
        e.allow(balances[user], user);

        emit Withdrawn(user, 0); // Amount is encrypted, so we emit 0
    }

    /// @notice Get encrypted balance of a user
    function balanceOf(address user) public view returns (euint256) {
        return balances[user];
    }

    /// @notice Request decryption of a user's balance (owner only)
    function requestUserBalanceDecryption(
        address user
    ) public onlyOwner returns (uint256) {
        euint256 encryptedBalance = balances[user];
        e.allow(encryptedBalance, address(this));

        uint256 requestId = e.requestDecryption(
            encryptedBalance,
            this.onDecryptionCallback.selector,
            ""
        );
        requestIdToUserAddress[requestId] = user;
        return requestId;
    }

    /// @notice Callback function for decryption
    function onDecryptionCallback(
        uint256 requestId,
        bytes32 _decryptedAmount,
        bytes memory data
    ) public returns (bool) {
        address userAddress = requestIdToUserAddress[requestId];
        emit UserBalanceDecrypted(userAddress, uint256(_decryptedAmount));
        return true;
    }
}
