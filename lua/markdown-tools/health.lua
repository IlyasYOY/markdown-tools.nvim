local M = {}

local function parser_available(language)
    local ok, parser = pcall(vim.treesitter.get_string_parser, "", language)
    return ok and parser ~= nil
end

function M.check()
    local config = require("markdown-tools.config").get()
    vim.health.start "markdown-tools.nvim"
    vim.health.ok("Neovim " .. tostring(vim.version()))

    for _, language in ipairs { "markdown", "markdown_inline" } do
        if parser_available(language) then
            vim.health.ok(language .. " Tree-sitter parser is available")
        else
            vim.health.warn(
                language
                    .. " Tree-sitter parser is unavailable; link wrapping will use the scanner fallback"
            )
        end
    end

    for _, executable in ipairs { config.pdf.pandoc, config.pdf.typst } do
        if vim.fn.executable(executable) == 1 then
            vim.health.ok(executable .. " is executable")
        else
            vim.health.warn(
                executable
                    .. " is not executable; PDF generation is unavailable"
            )
        end
    end
end

return M
