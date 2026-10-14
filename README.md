# Company.md (COMD)

`src/CompanyToken.sol:CompanyToken` is a fixed-supply ERC-20. It mints the entire
supply to its immediate deployer once, during construction.

| Parameter | Value |
| --- | --- |
| Solidity contract | `CompanyToken` |
| Token name | `Company.md` |
| Symbol | `COMD` |
| Decimals | `18` |
| Whole-token supply | `1,000,000,000` |
| Supply in base units | `1000000000000000000000000000` (`10^27`) |
| Constructor arguments | None (`[]`) |
| Constructor ETH value | `0` |
| Initial recipient | `msg.sender`, the address executing CREATE/CREATE2 |
| Owner / administrator | None |

## Behavior and assumptions

The task specifies no custom transfer rules, so COMD uses the unmodified
OpenZeppelin Contracts v5.4.0 ERC-20 implementation. All successful transfers
deliver the exact amount and return `true`. Failed operations revert with ERC-20
custom errors. Transfers to the zero address fail, including zero-value
transfers. Zero-value transfers between valid addresses succeed and emit
`Transfer`; self-transfers preserve the balance and still require sufficient
funds. The constructor emits a single mint `Transfer` event from the zero address.

Approvals replace the existing allowance and emit `Approval`. Finite allowances
decrease on `transferFrom`; `type(uint256).max` represents unlimited allowance
and does not decrease. As in OpenZeppelin v5, `transferFrom` emits `Transfer`
without emitting an additional `Approval` event for the allowance decrease.
Integrators should query `allowance` when they need its current value.

`INITIAL_SUPPLY` is the sole application constant and equals the requested supply
in base units. There are no fees, taxes, rebases, mint or burn entry points,
ownership roles, pauses, blacklists, upgrade mechanisms, or external callbacks.
The deployer has no special powers after receiving the initial balance. Supply
remains fixed; tokens sent to inaccessible addresses are not subtracted from
`totalSupply`.

## Build and check

Use Foundry with Solidity **0.8.26** available locally. The root `foundry.toml`
pins that compiler, the Cancun EVM target, optimizer settings (200 runs), and
`bytecode_hash = "none"`. Ethereum supports this EVM target. Dependencies are
vendored as ordinary source files under `lib/`; no dependency download, submodule,
RPC, key, FFI, or filesystem cheatcode permission is needed to build or test.
See [DEPENDENCIES.md](DEPENDENCIES.md) for versions, provenance, and licenses.

```sh
forge build
FOUNDRY_FUZZ_SEED=0x5c026568082186fa3ee387f5b15128ede2700d32cb6edc56d07659dadbe88fcb forge test
forge fmt --check
```

An installed compiler also permits `forge build --offline` and `forge test
--offline`. Tests do not read or mutate environment variables, use live networks,
or share state. The command above supplies the assignment's seed to Foundry;
the tests themselves receive their inputs through the fuzzing engine.

The suite covers metadata, mint events, CREATE2 deployment through a factory,
exact distribution/claim/pool-side transfers, approvals and revocations,
insufficient balances/allowances, zero-address failures, atomic rollback,
self-transfers, unlimited approvals, absent privileged entry points, rejected
ETH transfers, and runtime opcode/size checks. Four fuzz tests run 1,024 cases
each. Two stateful invariants run 128 sequences of 64 operations each, checking
fixed supply and balance conservation across transfers, approvals, and delegated
transfers.

The pool fixture checks ERC-20 balance movement only. It is not a Uniswap pool
or a full launch integration test. The supplied protected tests depend on the
network's separate factory/pool harness and launch manifest; that system runs
them during independent verification.

## Deployment parameters and responsibilities

Deploy the creation bytecode for **`src/CompanyToken.sol:CompanyToken`**, with no
appended constructor arguments and zero ETH. The artifact is
`out/CompanyToken.sol/CompanyToken.json`; it has no external library links.
`forge inspect src/CompanyToken.sol:CompanyToken bytecode` prints the creation
bytecode for inspection without sending a transaction.

For the specified Ethereum launch (chain ID 1), the factory is the immediate
deployer and receives all `10^27` base units. The transaction sender and requester
do not receive tokens from the constructor. A direct wallet deployment would
instead give that wallet the entire supply. Deploying a separate proxy is not
supported: this contract uses constructor initialization.

The launch infrastructure is responsible for its subsequent distribution: 10%
to the swarm distributor, 80% to pool seeding, and the remaining 10% to
`0xbb85c1b7540d9e7b56f7a595fc1ff7dd07cb0823`. These transfers are not performed or
reserved in the token constructor. The paired IMD token, pool configuration,
initial market cap, launch manifest, deployment, and source verification belong
to that launch infrastructure. This project contains only the requested token;
it needs no application contracts or token-specific launch settings.

### After launch

No token initialization calls, owner settings, or recurring maintenance are
required. The launch operator should confirm the address and chain, verified
source/compiler settings, token metadata, constructor mint, exact total supply,
and distribution receipts. The operator supplies the manifest and performs the
separate launch/integration verification and independent review before release.

Holders control transfers and approvals. They should verify recipients and
spender contracts, approve only the amount needed, and revoke unused allowances.
When changing an existing nonzero allowance, setting it to zero and confirming
that transaction before granting a new amount reduces the standard ERC-20
approval replacement race; it cannot undo spending already authorized.

There is no administrator recovery function. COMD or other assets sent to this
token contract or an inaccessible address may be permanently locked. Ordinary
ETH transfers revert. No operator can repair balances, freeze holders, issue more
COMD, or upgrade the deployed code. Local testing is not an independent security
audit; see [SECURITY.md](SECURITY.md) for the review scope.
