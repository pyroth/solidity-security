// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "forge-std/Test.sol";

/// @notice Vulnerable lottery contract with hidden assembly-based backdoor
/// @dev Admin can manipulate winner through low-level storage access, bypassing access controls
contract VulnerableLottery {
    uint256 public prize;
    address public winner;
    address public admin;

    constructor() {
        prize = 1000;
        admin = msg.sender;
    }

    modifier onlyAdmin() {
        require(msg.sender == _getAdmin(), "Unauthorized");
        _;
    }

    /// @dev Hidden backdoor: loads admin from storage slot 2 via assembly
    function _getAdmin() internal view returns (address adminAddress) {
        assembly {
            adminAddress := sload(2)
        }
    }

    /// @notice Appears to randomly select winner, but admin can manipulate via assembly
    /// @dev Backdoor: directly writes to storage slot 1 (winner) when called by admin
    function selectWinner(address candidate) external onlyAdmin {
        assembly {
            sstore(1, candidate)
        }
    }

    function getWinner() external view returns (address) {
        return winner;
    }
}

/// @notice Secure lottery contract with transparent access controls
/// @dev Uses explicit state variables and proper access modifiers without assembly tricks
contract SecureLottery {
    uint256 public prize;
    address public winner;
    address public immutable admin;

    event WinnerSelected(address indexed winner, uint256 prize);

    constructor() {
        prize = 1000;
        admin = msg.sender;
    }

    modifier onlyAdmin() {
        require(msg.sender == admin, "Unauthorized: caller is not admin");
        _;
    }

    /// @notice Explicitly sets winner with proper access control and event emission
    /// @dev No hidden assembly manipulation, fully transparent operation
    function selectWinner(address candidate) external onlyAdmin {
        require(candidate != address(0), "Invalid winner address");
        winner = candidate;
        emit WinnerSelected(candidate, prize);
    }

    function getWinner() external view returns (address) {
        return winner;
    }
}

/// @title Assembly Backdoor Vulnerability Test Suite
/// @notice Demonstrates hidden backdoor exploitation via inline assembly storage manipulation
/// @dev Compares vulnerable assembly-based backdoor against secure explicit implementation
contract BackdoorAssemblyTest is Test {
    VulnerableLottery internal vulnerable;
    SecureLottery internal secure;

    address internal alice;
    address internal bob;
    address internal admin;

    function setUp() public {
        alice = vm.addr(1);
        bob = vm.addr(2);
        admin = address(this);

        vulnerable = new VulnerableLottery();
        secure = new SecureLottery();
    }

    /// @notice Demonstrates backdoor: admin bypasses apparent access controls via assembly
    function test_VulnerableBackdoorExploit() public {
        console.log("=== Vulnerable Contract Exploit ===");
        console.log("Initial winner:", vulnerable.winner());
        console.log("Prize pool:", vulnerable.prize());

        console.log("\nAlice attempts to call selectWinner (will fail):");
        vm.prank(alice);
        vm.expectRevert("Unauthorized");
        vulnerable.selectWinner(alice);

        console.log("\nAdmin exploits backdoor to set Bob as winner:");
        vulnerable.selectWinner(bob);

        address manipulatedWinner = vulnerable.winner();
        console.log("Manipulated winner:", manipulatedWinner);

        assertEq(manipulatedWinner, bob, "Admin should manipulate winner via backdoor");
        console.log("Exploit completed: Admin bypassed controls via assembly\n");
    }

    /// @notice Demonstrates secure implementation with transparent access controls
    function test_SecureImplementation() public {
        console.log("=== Secure Contract Implementation ===");
        console.log("Initial winner:", secure.winner());
        console.log("Prize pool:", secure.prize());

        console.log("\nAlice attempts to call selectWinner (will fail):");
        vm.prank(alice);
        vm.expectRevert("Unauthorized: caller is not admin");
        secure.selectWinner(alice);

        console.log("\nAdmin legitimately sets Bob as winner:");
        vm.expectEmit(true, false, false, true);
        emit SecureLottery.WinnerSelected(bob, 1000);
        secure.selectWinner(bob);

        address legitimateWinner = secure.winner();
        console.log("Legitimate winner:", legitimateWinner);

        assertEq(legitimateWinner, bob, "Admin should set winner through proper controls");
        console.log("Secure operation completed: Transparent access control enforced\n");
    }

    /// @notice Verifies storage layout vulnerability in VulnerableLottery
    function test_StorageLayoutExploit() public {
        console.log("=== Storage Layout Analysis ===");

        bytes32 slot0 = vm.load(address(vulnerable), bytes32(uint256(0)));
        bytes32 slot1 = vm.load(address(vulnerable), bytes32(uint256(1)));
        bytes32 slot2 = vm.load(address(vulnerable), bytes32(uint256(2)));

        console.log("Slot 0 (prize):", uint256(slot0));
        console.log("Slot 1 (winner):", address(uint160(uint256(slot1))));
        console.log("Slot 2 (admin):", address(uint160(uint256(slot2))));

        vulnerable.selectWinner(alice);

        bytes32 slot1After = vm.load(address(vulnerable), bytes32(uint256(1)));
        console.log("\nSlot 1 after exploit:", address(uint160(uint256(slot1After))));

        assertEq(address(uint160(uint256(slot1After))), alice, "Assembly directly modified storage slot 1");
    }
}
