# markdown-tools.nvim Agent Guidelines

- Support Neovim 0.11 and newer.
- Keep all commands and mappings buffer-local and mappings opt-in.
- Tree-sitter parsers, Pandoc, and Typst are optional runtime dependencies.
- Keep the scanner fallback deterministic and link wrapping idempotent.
- `make check` is the canonical format, lint, help, and test command.
- `make test NVIM_VERSION=v0.11.7` verifies minimum-version compatibility.
- `make test-pdf-e2e` runs the optional real Pandoc + Typst smoke test.
- Do not commit or push unless the user explicitly asks.
