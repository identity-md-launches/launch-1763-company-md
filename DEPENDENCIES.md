# Vendored dependencies

All dependencies are ordinary files. No install step or network access is needed
after checkout. Only the following upstream source subsets are included; their
contents and license notices are unmodified.

| Dependency | Pinned release | Vendored subset | License |
| --- | --- | --- | --- |
| [OpenZeppelin Contracts](https://github.com/OpenZeppelin/openzeppelin-contracts/tree/v5.4.0) | `v5.4.0` | `ERC20.sol`, `IERC20.sol`, `IERC20Metadata.sol`, `Context.sol`, `draft-IERC6093.sol` | MIT, `lib/openzeppelin-contracts/LICENSE` |
| [Forge Standard Library](https://github.com/foundry-rs/forge-std/tree/v1.9.7) | `v1.9.7` | `src/` (test helpers only) | MIT OR Apache-2.0, licenses in `lib/forge-std/` |

Fetched release archives:

- `https://codeload.github.com/OpenZeppelin/openzeppelin-contracts/tar.gz/refs/tags/v5.4.0`
  SHA-256: `b89829be48bc501051002191733268a93ef6e238a4bb65d8fd1cbdf3969050d1`
- `https://codeload.github.com/foundry-rs/forge-std/tar.gz/refs/tags/v1.9.7`
  SHA-256: `45157353ab49eab01d294565866731e599b32401757229689ee459aa26b7ee94`

`DEPENDENCIES.sha256` records the SHA-256 of every vendored file. Verify locally:

```sh
sha256sum --check DEPENDENCIES.sha256
```

The Solidity compiler is a Foundry toolchain prerequisite, not a vendored
dependency; its exact version is pinned in `foundry.toml`.
