local pdf = require "markdown-tools.pdf"

local function config(overrides)
    return vim.tbl_deep_extend("force", {
        pandoc = "true",
        typst = "true",
        toc = true,
        toc_depth = 3,
        preprocess = nil,
        output_path = nil,
        extra_args = {},
    }, overrides or {})
end

describe("markdown-tools.pdf", function()
    local bufnr

    before_each(function()
        bufnr = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "# Document" })
        vim.api.nvim_buf_set_name(
            bufnr,
            vim.fs.joinpath(vim.fn.getcwd(), ".test-work", "document.md")
        )
    end)

    after_each(function()
        if vim.api.nvim_buf_is_valid(bufnr) then
            vim.api.nvim_buf_delete(bufnr, { force = true })
        end
    end)

    it("requires a named buffer", function()
        local unnamed = vim.api.nvim_create_buf(false, true)
        local handle, err = pdf.generate({ bufnr = unnamed }, config())
        vim.api.nvim_buf_delete(unnamed, { force = true })
        assert.is_nil(handle)
        assert.truthy(err:find("without a file path", 1, true))
    end)

    it("reports invalid hook results before spawning", function()
        local handle, err = pdf.generate(
            { bufnr = bufnr },
            config {
                output_path = function()
                    return ""
                end,
            }
        )
        assert.is_nil(handle)
        assert.truthy(err:find("non-empty string", 1, true))

        handle, err = pdf.generate(
            { bufnr = bufnr },
            config {
                preprocess = function()
                    return false
                end,
            }
        )
        assert.is_nil(handle)
        assert.truthy(err:find("must return a string", 1, true))
    end)
end)
