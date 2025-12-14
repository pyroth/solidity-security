// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/// @title Over-Permissive Approval Demonstration
/// @notice Demonstrates the risk of approving unlimited ERC20 allowances to untrusted addresses.
/// Alice grants Eve unlimited approval, allowing Eve to drain Alice's entire balance.
/// @dev This is a user-operation risk, not a contract vulnerability.
/// Mitigation: Approve only the exact amount required for a transaction.
/// Consider using permit() extensions for gasless approvals.

contract TestERC20 is ERC20 {
    constructor() ERC20("Test Token", "TEST") {}

    /// @dev Exposed mint for testing purposes only
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract ApproveScamTest is Test {
    TestERC20 internal token;

    address internal alice = vm.addr(1); // Private key 1
    address internal eve = vm.addr(2); // Private key 2

    uint256 internal constant INITIAL_SUPPLY = 1000 ether; // 1000 tokens with 18 decimals

    function setUp() public {
        token = new TestERC20();
        token.mint(alice, INITIAL_SUPPLY);
    }

    function test_overPermissiveApprovalExploit() public {
        // Initial state
        console.log("Eve balance before exploit:", token.balanceOf(eve));

        // Alice grants unlimited allowance to Eve (dangerous practice)
        vm.prank(alice);
        token.approve(eve, type(uint256).max);

        // Eve drains Alice's entire balance
        vm.prank(eve);
        token.transferFrom(alice, eve, INITIAL_SUPPLY);

        // Final state
        console.log("Eve balance after exploit :", token.balanceOf(eve));
        console.log("Exploit completed: Alice's funds fully transferred to Eve");
    }
}
