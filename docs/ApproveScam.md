# Over-Permissive Approval Risk in ERC20 Tokens

## Overview

The ERC20 `approve` function allows a token owner to grant a spender permission to transfer a specified amount of tokens on their behalf via `transferFrom`. A common user mistake is approving an excessively large allowance—often `type(uint256).max` (unlimited)—to an untrusted or malicious address.

Once granted, this allowance persists indefinitely until explicitly revoked or reduced. A malicious spender can then call `transferFrom` at any time to drain the owner's entire balance (up to the approved amount).

This is not a vulnerability in the ERC20 standard itself but a user-operation risk exploited in many phishing scams and malicious dApps.

## Demonstration

The following Foundry test illustrates the risk:

- Alice receives 1000 TEST tokens.
- Alice approves Eve for an unlimited allowance.
- Eve immediately transfers all of Alice's tokens to herself.

## Mitigation

- Approve only the exact amount required for the intended transaction.
- Use `increaseAllowance`/`decreaseAllowance` for incremental adjustments.
- Prefer tokens supporting EIP-2612 `permit` for off-chain signed approvals (no initial `approve` transaction needed).
- Regularly check and revoke unnecessary approvals using tools like Revoke.cash or Etherscan's Token Approval checker.

## Running the Test

```bash
forge test --match-contract ApproveScamTest -vv
```

The `-vv` flag displays console.log output, showing Eve's balance change from 0 to 1000 tokens after the exploit.

## Expected Output

```bash
[PASS] test_overPermissiveApprovalExploit() (gas: 75653)
Logs:
  Eve balance before exploit: 0
  Eve balance after exploit : 1000000000000000000000
  Exploit completed: Alice's funds fully transferred to Eve

Suite result: ok. 1 passed; 0 failed; 0 skipped; finished in 3.95ms
```

The logs confirm Eve's balance increases from 0 to 1,000 tokens (10¹⁸ wei units) after the exploit.
