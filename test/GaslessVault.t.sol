// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {GaslessVault} from "../src/GaslessVault.sol";

/// @notice Uses vm.sign to generate real EIP-712 signatures from a test private key.
/// No fork needed — pure EVM arithmetic.
contract GaslessVaultTest is Test {
    GaslessVault vault;
    address      token = address(0xBEEF);

    uint256 constant OWNER_PK = 0xA11CE;
    address         owner;
    uint256 constant AMOUNT   = 500e18;
    uint256          deadline;

    function setUp() public {
        owner    = vm.addr(OWNER_PK);
        vault    = new GaslessVault(token);
        deadline = block.timestamp + 1 hours;

        // Stub transferFrom so token doesn't need to exist
        vm.mockCall(token, abi.encodeWithSignature("transferFrom(address,address,uint256)"), abi.encode(true));
        vm.mockCall(token, abi.encodeWithSignature("transfer(address,uint256)"),             abi.encode(true));
    }

    function _sign(address _owner, uint256 amount, uint256 nonce, uint256 _deadline)
        internal view returns (uint8 v, bytes32 r, bytes32 s)
    {
        bytes32 structHash = keccak256(abi.encode(
            vault.PERMIT_TYPEHASH(), _owner, amount, nonce, _deadline
        ));
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", vault.DOMAIN_SEPARATOR(), structHash));
        (v, r, s) = vm.sign(OWNER_PK, digest);
    }

    function testDepositWithValidPermit() public {
        (uint8 v, bytes32 r, bytes32 s) = _sign(owner, AMOUNT, 0, deadline);
        vault.depositWithPermit(owner, AMOUNT, deadline, v, r, s);

        assertEq(vault.balances(owner), AMOUNT);
        assertEq(vault.nonces(owner), 1);
    }

    function testRejectsReplayedPermit() public {
        (uint8 v, bytes32 r, bytes32 s) = _sign(owner, AMOUNT, 0, deadline);
        vault.depositWithPermit(owner, AMOUNT, deadline, v, r, s);

        // Same sig again — nonce is now 1, but sig was made for nonce 0 → invalid
        vm.expectRevert("Invalid signature");
        vault.depositWithPermit(owner, AMOUNT, deadline, v, r, s);
    }

    function testRejectsExpiredPermit() public {
        uint256 pastDeadline = block.timestamp - 1;
        (uint8 v, bytes32 r, bytes32 s) = _sign(owner, AMOUNT, 0, pastDeadline);

        vm.expectRevert("Permit expired");
        vault.depositWithPermit(owner, AMOUNT, pastDeadline, v, r, s);
    }

    function testRejectsWrongSigner() public {
        // Sign with a different private key
        (uint8 v, bytes32 r, bytes32 s) = _sign(vm.addr(0xBAD), AMOUNT, 0, deadline);

        vm.expectRevert("Invalid signature");
        vault.depositWithPermit(owner, AMOUNT, deadline, v, r, s);
    }

    function testWithdraw() public {
        (uint8 v, bytes32 r, bytes32 s) = _sign(owner, AMOUNT, 0, deadline);
        vault.depositWithPermit(owner, AMOUNT, deadline, v, r, s);

        vm.prank(owner);
        vault.withdraw(AMOUNT);

        assertEq(vault.balances(owner), 0);
    }
}
