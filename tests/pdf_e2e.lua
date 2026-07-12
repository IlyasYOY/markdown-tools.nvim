local M = {}

function M.run()
    local root = vim.fn.getcwd()
    local test_work = vim.env.MARKDOWN_TOOLS_TEST_WORK
        or vim.fs.joinpath(root, ".test-work")
    local input = vim.fs.joinpath(test_work, "pdf", "sample.md")
    local output = vim.fs.joinpath(test_work, "pdf", "sample.pdf")
    vim.cmd.edit(vim.fn.fnameescape(input))
    vim.bo.filetype = "markdown"
    require("markdown-tools").setup()

    local done
    local result
    local handle, err = require("markdown-tools").generate_pdf {
        bufnr = 0,
        on_complete = function(completed)
            result = completed
            done = true
        end,
    }
    assert(handle, err)
    assert(
        vim.wait(30000, function()
            return done
        end, 20),
        "PDF generation timed out"
    )
    assert(result.ok, result.stderr)
    assert(result.output_path == output, result.output_path)
    local header = vim.fn.readfile(output, "b", 1)[1] or ""
    assert(header:sub(1, 4) == "%PDF", "output is not a PDF")
    print("ok - generated " .. output)
end

return M
