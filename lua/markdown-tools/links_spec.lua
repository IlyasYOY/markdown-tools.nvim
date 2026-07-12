local links = require "markdown-tools.links"

local function equal(actual, expected)
    assert(
        vim.deep_equal(actual, expected),
        vim.inspect {
            expected = expected,
            actual = actual,
        }
    )
end

local function wrap(lines, opts)
    opts = vim.tbl_extend("force", { treesitter = false }, opts or {})
    return links.wrap_lines(lines, opts)
end

return {
    {
        name = "wraps URLs and POSIX paths while preserving punctuation",
        run = function()
            local actual, result = wrap {
                "See https://example.com/a_(b)). and ./docs/readme.md.",
                "Use ../notes/todo.md, /tmp/report.pdf; or ~/vault/index.md!",
                "Do not treat and/or as a path.",
            }
            equal(actual, {
                "See <https://example.com/a_(b)>). and <./docs/readme.md>.",
                "Use <../notes/todo.md>, </tmp/report.pdf>; or <~/vault/index.md>!",
                "Do not treat and/or as a path.",
            })
            assert(result.replacements == 5, result.replacements)
        end,
    },
    {
        name = "protects Markdown syntax and YAML frontmatter",
        run = function()
            local input = {
                "---",
                "url: https://frontmatter.example",
                "---",
                "`https://inline.example ./inline`",
                "[inline](https://destination.example/a)",
                "![image](./images/picture.png)",
                "[reference][docs] and [docs]",
                "[docs]: https://reference.example",
                "<https://already.example> <./already/path.md>",
                "<mailto:person@example.com>",
                "https://wrap.example ./wrap/me.md",
                "```lua",
                "https://fenced.example ./fenced",
                "```",
                "~~~",
                "/also/protected",
                "~~~",
            }
            local actual, result = wrap(input)
            local expected = vim.deepcopy(input)
            expected[11] = "<https://wrap.example> <./wrap/me.md>"
            equal(actual, expected)
            assert(result.replacements == 2, result.replacements)
        end,
    },
    {
        name = "is idempotent",
        run = function()
            local first, first_result = wrap {
                "https://example.com ./notes/file.md /tmp/file.txt",
            }
            local second, second_result = wrap(first)
            equal(second, first)
            assert(first_result.replacements == 3)
            assert(second_result.replacements == 0)
        end,
    },
    {
        name = "limits replacements to the requested line range",
        run = function()
            local actual, result = wrap({
                "https://one.example",
                "https://two.example",
                "https://three.example",
            }, { line1 = 2, line2 = 2 })
            equal(actual, {
                "https://one.example",
                "<https://two.example>",
                "https://three.example",
            })
            assert(result.replacements == 1)
        end,
    },
}
