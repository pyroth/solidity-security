# Solidity Security Demonstrations

A curated collection of Foundry-based tests demonstrating common security risks and user-operation vulnerabilities in Solidity smart contracts.

The primary goal is educational: to illustrate real-world attack vectors, their exploitation mechanisms, and effective mitigations through clear, executable examples.

## Usage

Run all tests:

```bash
forge test
```

Run a specific test with verbose output:

```bash
forge test --match-path test/ApproveScam.t.sol -vv
```

## Structure

Each demonstration is implemented as a standalone Foundry test in the `test/` directory. Additional demonstrations will be added progressively.

| Code File                | Documentation File       | Description                                      |
|--------------------------|--------------------------|--------------------------------------------------|
| [`test/ApproveScam.t.sol`](test/ApproveScam.t.sol) | [`docs/ApproveScam.md`](docs/ApproveScam.md)    | Over-Permissive Approval Risk in ERC20 Tokens |
| [`test/ArrayDeletion.t.sol`](test/ArrayDeletion.t.sol) | [`docs/ArrayDeletion.md`](docs/ArrayDeletion.md)    | Improper Array Element Deletion Vulnerability |
| [`test/BackdoorAssembly.t.sol`](test/BackdoorAssembly.t.sol) | [`docs/BackdoorAssembly.md`](docs/BackdoorAssembly.md)    | Hidden Assembly Backdoor Vulnerability |
| [`test/BackdoorAssemblyV2.t.sol`](test/BackdoorAssemblyV2.t.sol) | [`docs/BackdoorAssemblyV2.md`](docs/BackdoorAssemblyV2.md)    | Hidden assembly backdoor vulnerability V2 |

## Inspiration

Heavily inspired by:

- [SunWeb3Sec/DeFiVulnLabs](https://github.com/SunWeb3Sec/DeFiVulnLabs)

## Disclaimer

This repository contains proof-of-concept code that intentionally demonstrates insecure patterns and exploitation techniques in smart contracts.

The content is strictly for educational and research purposes only. It must not be used for any illegal activities, unauthorized access, or exploitation of production systems.

Users bear full responsibility for any actions taken based on this material. All usage must comply with applicable laws, regulations, and ethical standards.
