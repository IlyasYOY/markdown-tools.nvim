local formatter = require "markdown-tools.format"

describe("markdown-tools.format", function()
    local bufnr

    before_each(function()
        bufnr = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "selected text" })
    end)

    after_each(function()
        if vim.api.nvim_buf_is_valid(bufnr) then
            vim.api.nvim_buf_delete(bufnr, { force = true })
        end
    end)

    local function range(end_col)
        return {
            start_row = 0,
            start_col = 0,
            end_row = 0,
            end_col = end_col,
        }
    end

    it("applies inline delimiters to an explicit range", function()
        local ok, err = formatter.apply("bold", {
            bufnr = bufnr,
            range = range(8),
        })
        assert.is_true(ok, err)
        assert.equal(
            "**selected** text",
            vim.api.nvim_buf_get_lines(bufnr, 0, 1, false)[1]
        )
    end)

    it("keeps code inline outside linewise visual mode", function()
        local ok, err = formatter.apply("code", {
            bufnr = bufnr,
            range = range(8),
        })
        assert.is_true(ok, err)
        assert.equal(
            "`selected` text",
            vim.api.nvim_buf_get_lines(bufnr, 0, 1, false)[1]
        )
    end)

    it("wraps a linewise selection in a fenced code block", function()
        vim.api.nvim_buf_set_lines(
            bufnr,
            0,
            -1,
            false,
            { "first line", "  second line", "after" }
        )
        vim.api.nvim_set_current_buf(bufnr)
        vim.api.nvim_win_set_cursor(0, { 1, 0 })
        vim.cmd.normal "Vj"
        local ok, err = formatter.apply("code", { bufnr = bufnr })
        assert.is_true(ok, err)
        assert.same({
            "```",
            "first line",
            "  second line",
            "```",
            "after",
        }, vim.api.nvim_buf_get_lines(bufnr, 0, -1, false))
    end)

    it("formats a link with an explicit target", function()
        local ok, err = formatter.apply("link", {
            bufnr = bufnr,
            range = range(8),
            target = "https://example.com",
        })
        assert.is_true(ok, err)
        assert.equal(
            "[selected](https://example.com) text",
            vim.api.nvim_buf_get_lines(bufnr, 0, 1, false)[1]
        )
    end)

    it("rejects unknown formatting kinds", function()
        local ok, err = formatter.apply("unknown", {
            bufnr = bufnr,
            range = range(8),
        })
        assert.is_nil(ok)
        assert.truthy(err:find("unknown formatting kind", 1, true))
    end)
end)
