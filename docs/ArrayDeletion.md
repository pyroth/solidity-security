# Improper Array Element Deletion Vulnerability

## Overview

Dynamic arrays in Solidity support the `delete` keyword to remove elements, but using `delete array[index]` does **not** reduce the array's length. Instead, it zeroes out the element at the specified index, leaving a gap in the array. This creates data inconsistencies and can lead to logic errors in contracts that iterate over arrays or assume contiguous data.

The array retains its original length, and subsequent iterations will encounter zero values where elements were "deleted." This is a common pitfall in dynamic array management that can cause unexpected behavior in production contracts.

This is not a compiler bug but a language design choice—developers must explicitly manage array length when removing elements.

## Demonstration

The following Foundry test illustrates the vulnerability:

- An array `[1, 2, 3, 4, 5]` is initialized with length 5.
- The vulnerable contract uses `delete items[1]` to remove the element at index 1.
- The array becomes `[1, 0, 3, 4, 5]` with length still 5 (zero-value gap created).
- The secure contract uses swap-and-pop to properly remove the element.
- The array becomes `[1, 5, 3, 4]` with length reduced to 4 (no gaps).

## Mitigation

### Recommended: Swap-and-Pop Pattern (O(1))

Replace the target element with the last element, then pop:

```solidity
function removeElement(uint256 index) external {
    require(index < items.length, "Index out of bounds");
    items[index] = items[items.length - 1];
    items.pop();
}
```

**Trade-off:** Does not preserve array order. Suitable when element order is irrelevant.

### Alternative: Shift-Left Pattern (O(n))

Shift all elements after the target index left by one position, then pop:

```solidity
function removeElement(uint256 index) external {
    require(index < items.length, "Index out of bounds");
    for (uint256 i = index; i < items.length - 1; i++) {
        items[i] = items[i + 1];
    }
    items.pop();
}
```

**Trade-off:** Preserves array order but costs significantly more gas for large arrays.

### Best Practices

- Never use `delete array[index]` unless you explicitly want to zero an element while maintaining length.
- Choose swap-and-pop for gas efficiency when order doesn't matter.
- Use shift-left only when order preservation is critical and array size is small.
- Consider using mapping-based structures if frequent deletions are required.

## Running the Test

```bash
forge test --match-contract ArrayDeletionTest -vv
```

The `-vv` flag displays console.log output, showing the array length and element values before and after deletion.

## Expected Output

```bash
[PASS] test_SecureArrayDeletion() (gas: 29046)
Logs:
  Initial length: 5
  Element at index 1: 2
  Final length: 4
  Element at index 1: 5

[PASS] test_VulnerableArrayDeletion() (gas: 20588)
Logs:
  Initial length: 5
  Element at index 1: 2
  Final length: 5
  Element at index 1: 0

Suite result: ok. 2 passed; 0 failed; 0 skipped; finished in 512.41µs (268.97µs CPU time)
```

The logs confirm:

- **Vulnerable pattern:** Length remains 5, element becomes 0 (gap created).
- **Secure pattern:** Length reduces to 4, element becomes 5 (last element swapped in, no gap).

## Real-World Impact

This vulnerability has appeared in multiple audit reports:

- **Gas inefficiency:** Iterating over arrays with gaps wastes gas on zero-value checks.
- **Logic errors:** Contracts assuming contiguous data may skip valid elements or process zeros incorrectly.
- **State corruption:** Off-chain indexers and frontends may display incorrect data if they don't account for gaps.

Always validate array deletion logic during security audits and ensure proper length management.
