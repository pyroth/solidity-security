// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "forge-std/Test.sol";

/// @notice Vulnerable contract demonstrating improper array element deletion
/// @dev Using 'delete' on array elements creates zero-value gaps without reducing length
contract VulnerableArrayDeletion {
    uint256[] public items;

    constructor() {
        items = [1, 2, 3, 4, 5];
    }

    function removeElement(uint256 index) external {
        require(index < items.length, "Index out of bounds");
        delete items[index];
    }

    function length() external view returns (uint256) {
        return items.length;
    }
}

/// @notice Secure contract demonstrating proper array element deletion via swap-and-pop
/// @dev Achieves O(1) deletion by replacing target with last element, then popping
/// @dev Alternative: shift-left approach preserves order but costs O(n) gas
contract SecureArrayDeletion {
    uint256[] public items;

    constructor() {
        items = [1, 2, 3, 4, 5];
    }

    function removeElement(uint256 index) external {
        require(index < items.length, "Index out of bounds");
        items[index] = items[items.length - 1];
        items.pop();
    }

    function length() external view returns (uint256) {
        return items.length;
    }
}

/// @title Array Deletion Vulnerability Test Suite
/// @notice Demonstrates the security implications of improper array element deletion
/// @dev Compares vulnerable 'delete' pattern against secure swap-and-pop mitigation
contract ArrayDeletionTest is Test {
    VulnerableArrayDeletion internal vulnerable;
    SecureArrayDeletion internal secure;

    function setUp() public {
        vulnerable = new VulnerableArrayDeletion();
        secure = new SecureArrayDeletion();
    }

    /// @notice Demonstrates vulnerability: 'delete' creates gaps without reducing length
    function test_VulnerableArrayDeletion() public {
        uint256 initialLength = vulnerable.length();
        uint256 targetIndex = 1;
        uint256 targetValue = vulnerable.items(targetIndex);

        console.log("Initial length:", initialLength);
        console.log("Element at index %s:", targetIndex, targetValue);

        vulnerable.removeElement(targetIndex);

        uint256 finalLength = vulnerable.length();
        uint256 finalValue = vulnerable.items(targetIndex);

        console.log("Final length:", finalLength);
        console.log("Element at index %s:", targetIndex, finalValue);

        assertEq(finalLength, initialLength, "Length should remain unchanged");
        assertEq(finalValue, 0, "Element should be zeroed");
    }

    /// @notice Demonstrates mitigation: swap-and-pop properly reduces array length
    function test_SecureArrayDeletion() public {
        uint256 initialLength = secure.length();
        uint256 targetIndex = 1;
        uint256 targetValue = secure.items(targetIndex);

        console.log("Initial length:", initialLength);
        console.log("Element at index %s:", targetIndex, targetValue);

        secure.removeElement(targetIndex);

        uint256 finalLength = secure.length();
        uint256 finalValue = secure.items(targetIndex);

        console.log("Final length:", finalLength);
        console.log("Element at index %s:", targetIndex, finalValue);

        assertEq(finalLength, initialLength - 1, "Length should decrease by 1");
        assertNotEq(finalValue, 0, "No zero-value gap should exist");
    }
}
