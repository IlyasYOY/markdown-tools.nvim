local M = {}

local defaults = {
    links = {
        enabled = true,
        treesitter = "auto",
        notify_fallback = true,
    },
    tasks = {
        enabled = true,
        marker = "-",
    },
    pdf = {
        enabled = true,
        pandoc = "pandoc",
        typst = "typst",
        toc = true,
        toc_depth = 3,
        preprocess = nil,
        output_path = nil,
        extra_args = {},
    },
    formatting = {
        enabled = true,
    },
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

local current = vim.deepcopy(defaults)

local function normalize_feature(value)
    if type(value) == "boolean" then
        return { enabled = value }
    end

    return value
end

local function normalize_options(opts)
    opts = vim.deepcopy(opts or {})
    for _, name in ipairs { "links", "tasks", "pdf", "formatting" } do
        opts[name] = normalize_feature(opts[name])
    end

    if opts.commands == false then
        opts.commands = {
            wrap_links = false,
            cycle_task = false,
            pdf = false,
        }
    end

    if opts.keymaps == false then
        opts.keymaps = vim.deepcopy(defaults.keymaps)
    end

    return opts
end

local function validate_string_or_false(name, value)
    if value ~= false and type(value) ~= "string" then
        error(name .. " must be a string or false")
    end
end

local function validate(config)
    if not vim.tbl_contains({ "-", "*", "+" }, config.tasks.marker) then
        error "tasks.marker must be '-', '*', or '+'"
    end

    if
        config.links.treesitter ~= "auto"
        and type(config.links.treesitter) ~= "boolean"
    then
        error "links.treesitter must be 'auto', true, or false"
    end

    if type(config.pdf.toc_depth) ~= "number" or config.pdf.toc_depth < 1 then
        error "pdf.toc_depth must be a positive number"
    end

    if
        config.pdf.preprocess ~= nil
        and type(config.pdf.preprocess) ~= "function"
    then
        error "pdf.preprocess must be a function or nil"
    end

    if
        config.pdf.output_path ~= nil
        and type(config.pdf.output_path) ~= "function"
    then
        error "pdf.output_path must be a function or nil"
    end

    if not vim.islist(config.pdf.extra_args) then
        error "pdf.extra_args must be a list"
    end

    for name, value in pairs(config.commands) do
        validate_string_or_false("commands." .. name, value)
    end
    for name, value in pairs(config.keymaps) do
        validate_string_or_false("keymaps." .. name, value)
    end
end

function M.resolve(opts)
    current = vim.tbl_deep_extend(
        "force",
        vim.deepcopy(defaults),
        normalize_options(opts)
    )
    validate(current)
    return current
end

function M.get()
    return current
end

function M.defaults()
    return vim.deepcopy(defaults)
end

return M
