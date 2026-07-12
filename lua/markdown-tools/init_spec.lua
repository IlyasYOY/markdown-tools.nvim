local markdown_tools = require "markdown-tools"

local test_work = vim.env.MARKDOWN_TOOLS_TEST_WORK
    or vim.fs.joinpath(vim.fn.getcwd(), ".test-work")

describe("markdown-tools integration", function()
    local buffers
    local original_buf
    local original_get_parser
    local original_notify
    local original_system

    local function test_path(name)
        return vim.fs.joinpath(test_work, name)
    end

    local function markdown_buffer(lines, name)
        local bufnr = vim.api.nvim_create_buf(false, true)
        buffers[#buffers + 1] = bufnr
        vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines or { "" })
        if name then
            vim.api.nvim_buf_set_name(bufnr, name)
        end
        vim.bo[bufnr].filetype = "markdown"
        vim.api.nvim_set_current_buf(bufnr)
        return bufnr
    end

    before_each(function()
        buffers = {}
        original_buf = vim.api.nvim_get_current_buf()
        original_get_parser = vim.treesitter.get_parser
        original_notify = vim.notify
        original_system = vim.system
        vim.fn.mkdir(test_work, "p")
    end)

    after_each(function()
        vim.treesitter.get_parser = original_get_parser
        vim.notify = original_notify
        vim.system = original_system

        if vim.api.nvim_buf_is_valid(original_buf) then
            vim.api.nvim_set_current_buf(original_buf)
        end
        for index = #buffers, 1, -1 do
            local bufnr = buffers[index]
            if vim.api.nvim_buf_is_valid(bufnr) then
                vim.api.nvim_buf_delete(bufnr, { force = true })
            end
        end
        markdown_tools.setup()
    end)

    it("creates namespaced commands and opt-in mappings", function()
        local bufnr = markdown_buffer { "text" }
        markdown_tools.setup {
            links = { treesitter = false },
            keymaps = { cycle_task = ",t" },
        }
        local commands = vim.api.nvim_buf_get_commands(bufnr, {})
        assert(commands.MarkdownToolsWrapLinks)
        assert(commands.MarkdownToolsCycleTask)
        assert(commands.MarkdownToolsPdf)
        local maps = vim.api.nvim_buf_get_keymap(bufnr, "n")
        assert(vim.iter(maps):any(function(mapping)
            return mapping.lhs == ",t"
        end))
        assert(not vim.iter(maps):any(function(mapping)
            return mapping.lhs == ",L"
        end))
    end)

    it("can rename commands and disable features", function()
        local bufnr = markdown_buffer { "text" }
        markdown_tools.setup {
            links = false,
            pdf = false,
            commands = { cycle_task = "MarkdownTask" },
        }
        local commands = vim.api.nvim_buf_get_commands(bufnr, {})
        assert(not commands.MarkdownToolsWrapLinks)
        assert(not commands.MarkdownToolsPdf)
        assert(commands.MarkdownTask)
    end)

    it("wraps links and cycles tasks through the buffer API", function()
        local bufnr = markdown_buffer { "  https://example.com" }
        markdown_tools.setup { links = { treesitter = false } }
        local wrapped = markdown_tools.wrap_links { bufnr = bufnr }
        assert(wrapped.replacements == 1)
        local cycled = assert(markdown_tools.cycle_task {
            bufnr = bufnr,
            row = 0,
        })
        assert(cycled.to == "list")
        local line = vim.api.nvim_buf_get_lines(bufnr, 0, 1, false)[1]
        assert(line == "  - <https://example.com>", line)
    end)

    it("reports the scanner fallback once per buffer", function()
        local bufnr =
            markdown_buffer { "https://one.example https://two.example" }
        local warnings = 0
        vim.treesitter.get_parser = function()
            error "parser missing"
        end
        vim.notify = function(_, level)
            if level == vim.log.levels.WARN then
                warnings = warnings + 1
            end
        end
        markdown_tools.setup()

        local first = markdown_tools.wrap_links {
            bufnr = bufnr,
            line1 = 1,
            line2 = 1,
        }
        local second = markdown_tools.wrap_links {
            bufnr = bufnr,
            line1 = 1,
            line2 = 1,
        }

        assert(first.used_fallback)
        assert(second.used_fallback)
        assert(first.replacements == 2)
        assert(second.replacements == 0)
        assert(warnings == 1, warnings)
    end)

    it("formats an explicit selection", function()
        local bufnr = markdown_buffer { "selected text" }
        markdown_tools.setup()
        local ok, err = markdown_tools.format_selection("link", {
            bufnr = bufnr,
            target = "https://example.com",
            range = {
                start_row = 0,
                start_col = 0,
                end_row = 0,
                end_col = 8,
            },
        })
        assert(ok, err)
        local line = vim.api.nvim_buf_get_lines(bufnr, 0, 1, false)[1]
        assert(line == "[selected](https://example.com) text", line)
    end)

    it("builds an asynchronous PDF job from current buffer content", function()
        local bufnr = markdown_buffer(
            { "# Current", "", "unsaved content" },
            test_path "markdown-tools-test.note.md"
        )
        local captured
        vim.system = function(argv, opts, callback)
            captured = { argv = argv, opts = opts }
            vim.schedule(function()
                callback { code = 0, signal = 0, stdout = "", stderr = "" }
            end)
            return { pid = 123 }
        end
        local completed
        local expected_input = vim.api.nvim_buf_get_name(bufnr)
        local expected_output = vim.fn.fnamemodify(expected_input, ":r")
            .. ".pdf"
        markdown_tools.setup {
            pdf = {
                pandoc = "true",
                typst = "true",
                preprocess = function(content, context)
                    assert(
                        context.output_path == expected_output,
                        context.output_path
                    )
                    return content .. "preprocessed\n"
                end,
            },
        }
        local handle, err = markdown_tools.generate_pdf {
            bufnr = bufnr,
            on_complete = function(result)
                completed = result
            end,
        }
        assert(handle, err)
        assert(vim.wait(1000, function()
            return completed ~= nil
        end))
        assert(completed.ok)
        assert(completed.output_path == expected_output)
        assert(captured.opts.cwd == vim.fs.dirname(expected_input))
        assert(captured.opts.stdin:match "unsaved content\npreprocessed\n$")
        assert(vim.tbl_contains(captured.argv, "--pdf-engine=true"))
        assert(vim.tbl_contains(captured.argv, "--toc-depth=3"))
    end)

    it("reports missing PDF executables before spawning", function()
        local bufnr = markdown_buffer({ "text" }, test_path "missing-tool.md")
        markdown_tools.setup {
            pdf = { pandoc = "markdown-tools-command-that-does-not-exist" },
        }
        local handle, err = markdown_tools.generate_pdf { bufnr = bufnr }
        assert(handle == nil)
        assert(err:match "is required", err)
    end)
end)
