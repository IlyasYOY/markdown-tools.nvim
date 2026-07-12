# markdown-tools.nvim

`markdown-tools.nvim` provides reusable Markdown link wrapping, task cycling,
visual formatting, and Pandoc + Typst PDF generation without depending on a
vault plugin, formatter, package manager, or personal paths.

## Requirements

- Neovim 0.11 or newer
- `markdown` and `markdown_inline` Tree-sitter parsers are optional; the link
  wrapper has a built-in scanner fallback
- Pandoc and Typst are required only by PDF generation

## Installation

With Neovim 0.12 or newer, use the built-in `vim.pack`:

```lua
vim.pack.add {
    { src = "https://github.com/IlyasYOY/markdown-tools.nvim" },
}
```

Then call `setup()`:

```lua
require("markdown-tools").setup()
```

Neovim 0.11 users should install the plugin with lazy.nvim or another package
manager.

With [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
    "IlyasYOY/markdown-tools.nvim",
    opts = {},
}
```

## Configuration

Commands are buffer-local. Keymaps are disabled by default to avoid collisions.

```lua
require("markdown-tools").setup {
    links = {
        enabled = true,
        treesitter = "auto", -- true, false, or "auto"
        notify_fallback = true,
    },
    tasks = {
        enabled = true,
        marker = "-", -- marker used when a plain line enters the cycle
    },
    pdf = {
        enabled = true,
        pandoc = "pandoc",
        typst = "typst",
        toc = true,
        toc_depth = 3,
        extra_args = {},
        preprocess = nil,
        output_path = nil,
    },
    formatting = { enabled = true },
    commands = {
        wrap_links = "MarkdownToolsWrapLinks",
        cycle_task = "MarkdownToolsCycleTask",
        pdf = "MarkdownToolsPdf",
    },
    keymaps = {
        wrap_links = false,
        cycle_task = false,
        pdf = false,
        italic = false,
        bold = false,
        code = false,
        link = false,
    },
}
```

Set a feature to `false` as shorthand for `{ enabled = false }`. Set an
individual command or keymap to `false` to disable it. Re-running `setup()`
removes registrations owned by this plugin before applying the new options.
Existing foreign buffer-local commands and mappings are preserved.

## Link wrapping

`:MarkdownToolsWrapLinks` wraps the whole buffer; an explicit Ex range limits
the changed lines. The wrapper recognizes HTTP(S) URLs and whitespace-free
POSIX-style paths beginning with `/`, `./`, `../`, or `~/`:

```markdown
https://example.com/docs, ./notes/todo.md.
```

becomes:

```markdown
<https://example.com/docs>, <./notes/todo.md>.
```

The angle-bracket form for file paths intentionally preserves the behavior
from which this plugin was extracted. Some Markdown renderers recognize only
URI schemes as formal autolinks.

YAML frontmatter, fenced and inline code, existing inline/reference links and
images, link definitions, URI autolinks, and already wrapped values are not
changed. Trailing punctuation and unmatched closing brackets remain outside
the wrapper. Running the wrapper repeatedly is idempotent.

When both Markdown parsers are available their syntax ranges augment the
built-in scanner. If either parser is missing, the command continues with the
scanner and warns once per buffer. Use `:checkhealth markdown-tools` for parser
and executable diagnostics. The `nvim-treesitter` plugin itself is not needed.

## Task cycle

`:MarkdownToolsCycleTask` changes the current physical line:

```text
line -> - line -> - [ ] line -> - [x] line -> line
```

Indentation is preserved. Existing `-`, `*`, and `+` markers are preserved;
`tasks.marker` is used only when a plain line enters the cycle. Task cycling is
line-based and does not require Tree-sitter.

## Visual formatting

Opt-in visual mappings call the same Lua API for `italic`, `bold`, `code`, and
`link`. The link helper prompts with `vim.ui.input()` and uses the `+` register
as its editable initial value. Cancelling the prompt or submitting an empty
target leaves the selection unchanged.

## PDF generation

`:MarkdownToolsPdf` checks both executables and starts Pandoc asynchronously
with the current in-memory buffer content on stdin. A named `note.md` buffer
produces `note.pdf` next to it; the source does not need to be saved first.
Concurrent jobs targeting the same output are rejected.

The default command uses GFM input, Typst as the PDF engine, colored links,
resource lookup relative to the source directory, and a depth-three table of
contents. `pdf.extra_args` appends structured Pandoc arguments.

The synchronous preprocess hook receives the current content and context:

```lua
require("markdown-tools").setup {
    pdf = {
        preprocess = function(content, context)
            -- context: bufnr, input_path, output_path, cwd
            return content:gsub("{{date}}", os.date "%F")
        end,
        output_path = function(context)
            return vim.fn.fnamemodify(context.input_path, ":r") .. ".pdf"
        end,
    },
}
```

The hook must return a string. An exception or invalid result aborts the job.
Pandoc overwrites an existing output file on success.

## Lua API

```lua
local markdown_tools = require "markdown-tools"

markdown_tools.attach(bufnr)
markdown_tools.wrap_links { bufnr = bufnr, line1 = 1, line2 = 20 }
markdown_tools.cycle_task { bufnr = bufnr, row = 0 }
markdown_tools.format_selection("bold", { bufnr = bufnr })
markdown_tools.generate_pdf {
    bufnr = bufnr,
    on_complete = function(result)
        -- result: ok, code, signal, stdout, stderr, output_path, argv
    end,
}
```

`wrap_links()` returns `{ replacements, used_fallback }`. `cycle_task()` returns
`{ row, from, to, line }`. `generate_pdf()` returns a `vim.SystemObj`, or
`nil, error` when preflight fails. Pure transformation helpers are available as
`require("markdown-tools").links.wrap_lines()` and
`require("markdown-tools").tasks.cycle_line()`.

## Health

Run `:checkhealth markdown-tools` to inspect Neovim, the optional Markdown
Tree-sitter parsers, and the Pandoc and Typst executables configured for PDF
generation. Missing optional tools are warnings and do not prevent the plugin
from loading.

See `:help markdown-tools` for the complete Vim help reference.

## Development

```bash
make check
make test NVIM_VERSION=v0.11.7
make test NVIM_VERSION=v0.12.4
make test NVIM_VERSION=nightly
make test-pdf-e2e
```

The first command is the canonical formatting, Luacheck, help, and isolated
Neovim test suite. The minimum-version target downloads Neovim when needed.
The PDF smoke test additionally requires real Pandoc and Typst executables.

## License

MIT
