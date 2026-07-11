// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transferFrom(address, address, uint256) external returns (bool);
    function transfer(address, uint256) external returns (bool);
    function balanceOf(address) external view returns (uint256);
}

/// @notice Gasless ERC-20 vault.
/// Users sign an EIP-712 permit off-chain (free). A relayer submits it on-chain.
/// The vault verifies the signature with ecrecover before moving tokens.
contract GaslessVault {
    IERC20 public immutable token;

    // EIP-712 domain — prevents replay across chains and contract addresses
    bytes32 public immutable DOMAIN_SEPARATOR;

    // keccak256("DepositPermit(address owner,uint256 amount,uint256 nonce,uint256 deadline)")
    bytes32 public constant PERMIT_TYPEHASH =
        keccak256("DepositPermit(address owner,uint256 amount,uint256 nonce,uint256 deadline)");

    mapping(address => uint256) public nonces;    // per-user replay guard
    mapping(address => uint256) public balances;  // vault balances

    event Deposited(address indexed owner, uint256 amount);
    event Withdrawn(address indexed owner, uint256 amount);

    constructor(address _token) {
        token = IERC20(_token);
        DOMAIN_SEPARATOR = keccak256(abi.encode(
            keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
            keccak256("GaslessVault"),
            keccak256("1"),
            block.chainid,
            address(this)
        ));
    }

    /// @notice Relayer calls this with the owner's off-chain EIP-712 signature.
    function depositWithPermit(
        address owner,
        uint256 amount,
        uint256 deadline,
        uint8   v,
        bytes32 r,
        bytes32 s
    ) external {
        require(block.timestamp <= deadline, "Permit expired");

        bytes32 structHash = keccak256(abi.encode(
            PERMIT_TYPEHASH,
            owner,
            amount,
            nonces[owner]++,
            deadline
        ));
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR, structHash));
        address signer = ecrecover(digest, v, r, s);

        require(signer != address(0) && signer == owner, "Invalid signature");

        balances[owner] += amount;
        token.transferFrom(owner, address(this), amount);

        emit Deposited(owner, amount);
    }

    /// @notice Owner withdraws their own balance directly (pays gas themselves).
    function withdraw(uint256 amount) external {
        require(balances[msg.sender] >= amount, "Insufficient balance");
        balances[msg.sender] -= amount;
        token.transfer(msg.sender, amount);

        emit Withdrawn(msg.sender, amount);
    }
}
