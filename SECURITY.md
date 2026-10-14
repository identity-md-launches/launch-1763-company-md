# Security review scope

CompanyToken adds one constructor and a supply constant to the vendored
OpenZeppelin ERC-20. The constructor mints exactly `10^27` units to `msg.sender`.
It makes no external calls. There are no public mint/burn functions, mutable
configuration, privileged roles, proxies, or arbitrary calls. ERC-20 transfers
and approvals never call recipients, so they expose no callback reentrancy path.

Local review checked the supplied security reference against the actual scope:

- Supply and decimals are fixed; unit, fuzz, and stateful invariant tests check
  allocation, conservation, and exact transfers.
- Only holders or their approved spenders can move balances. Deployer and
  stranger attempts to mint, burn, freeze, seize, or upgrade fail.
- Invalid receivers, insufficient balances, and insufficient allowances revert.
  Tests verify failed delegated transfers preserve balances and allowances.
- Self-transfers, zero-value transfers, entire-balance transfers, and maximum
  approvals are covered. Arithmetic follows the unmodified dependency.
- Runtime checks reject DELEGATECALL, CALLCODE, and SELFDESTRUCT opcodes and
  enforce the EIP-170 code-size limit. External library linking is unnecessary.
- Oracles, randomness, signatures, vault share accounting, and swap execution
  are outside this token's implementation.

Known operational properties include the standard ERC-20 allowance replacement
race, the ability of an approved spender to spend up to its allowance, and the
absence of recovery for misdirected assets. There is deliberately no governance
key or upgrade path to change those properties after deployment.

Validation uses Foundry build, unit/fuzz/invariant tests, and formatting checks.
Slither and Mythril were not run. The repository's pool transfer fixture does
not prove actual Uniswap integration; the network's protected launch checks
provide that separate verification. This local review is not an independent
audit. Deployment, block explorer verification, and an independent adversarial
review remain release responsibilities of the launch process.
