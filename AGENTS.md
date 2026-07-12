# markdown-tools.nvim Agent Guidelines

## Scope and compatibility

- Support Neovim 0.11 and newer.
- Preserve the setup options, Lua return values, and buffer-local commands
  documented in `README.md` and `doc/markdown-tools.txt`.
- Keep all mappings opt-in and all plugin commands and mappings buffer-local.
- Tree-sitter parsers, Pandoc, and Typst are optional runtime dependencies.
- Keep the scanner fallback deterministic, protected-range aware, and
  idempotent.
- Preserve asynchronous PDF generation, structured argv, in-memory input,
  output hooks, and per-output concurrency protection.

## Repository structure

- Runtime modules and their focused `*_spec.lua` files live together under
  `lua/markdown-tools/`.
- Plugin startup remains in `plugin/markdown-tools.lua`.
- Headless setup, the dependency-free runner, fixtures, and the real PDF smoke
  test live under `tests/`.
- Vim help lives in `doc/markdown-tools.txt`; keep `doc/tags` synchronized.
- Tests must isolate XDG state, logs, and generated files under ignored
  `.test-home/` and `.test-work/`.

## Development commands

- `make check` is the canonical non-mutating lint, test, and help check.
- `make test NVIM_VERSION=v0.11.7` verifies the minimum supported version.
- `make test NVIM_VERSION=v0.12.4` verifies the current stable version.
- `make test NVIM_VERSION=nightly` is the compatibility probe.
- `make test-pdf-e2e` runs the real Pandoc + Typst smoke test.
- `make format` formats Lua sources.

Do not commit, push, tag, or publish unless the user explicitly asks.
