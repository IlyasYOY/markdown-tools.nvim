local config_module = require "markdown-tools.config"
local links = require "markdown-tools.links"
local tasks = require "markdown-tools.tasks"
local formatter = require "markdown-tools.format"
local pdf = require "markdown-tools.pdf"

local M = {}

local state = {
    augroup = nil,
    commands = {},
    keymaps = {},
    attached = {},
}

local function notify(message, level)
    vim.notify("markdown-tools: " .. message, level or vim.log.levels.INFO)
end

local function cleanup()
    if state.augroup then
        pcall(vim.api.nvim_del_augroup_by_id, state.augroup)
        state.augroup = nil
    end
    for _, command in ipairs(state.commands) do
        if vim.api.nvim_buf_is_valid(command.bufnr) then
            pcall(
                vim.api.nvim_buf_del_user_command,
                command.bufnr,
                command.name
            )
        end
    end
    for _, keymap in ipairs(state.keymaps) do
        if vim.api.nvim_buf_is_valid(keymap.bufnr) then
            pcall(
                vim.keymap.del,
                keymap.mode,
                keymap.lhs,
                { buffer = keymap.bufnr }
            )
        end
    end
    state.commands = {}
    state.keymaps = {}
    state.attached = {}
end

local function create_command(bufnr, name, callback, opts)
    if name == false then
        return
    end
    local existing = vim.api.nvim_buf_get_commands(bufnr, {})
    if existing[name] then
        notify(
            "preserving existing buffer command :" .. name,
            vim.log.levels.WARN
        )
        return
    end
    local ok, err =
        pcall(vim.api.nvim_buf_create_user_command, bufnr, name, callback, opts)
    if not ok then
        notify(
            "could not create :" .. name .. ": " .. tostring(err),
            vim.log.levels.WARN
        )
        return
    end
    state.commands[#state.commands + 1] = { bufnr = bufnr, name = name }
end

local function has_buffer_map(bufnr, mode, lhs)
    for _, mapping in ipairs(vim.api.nvim_buf_get_keymap(bufnr, mode)) do
        if mapping.lhs == lhs then
            return true
        end
    end
    return false
end

local function create_keymap(bufnr, mode, lhs, callback, desc)
    if lhs == false then
        return
    end
    if has_buffer_map(bufnr, mode, lhs) then
        notify(
            "preserving existing buffer mapping " .. lhs,
            vim.log.levels.WARN
        )
        return
    end
    vim.keymap.set(mode, lhs, callback, {
        buffer = bufnr,
        silent = true,
        desc = "markdown-tools: " .. desc,
    })
    state.keymaps[#state.keymaps + 1] = {
        bufnr = bufnr,
        mode = mode,
        lhs = lhs,
    }
end

local function notify_fallback_once(bufnr, config)
    if not config.notify_fallback then
        return
    end
    local ok, notified = pcall(
        vim.api.nvim_buf_get_var,
        bufnr,
        "markdown_tools_fallback_notified"
    )
    if ok and notified then
        return
    end
    vim.api.nvim_buf_set_var(bufnr, "markdown_tools_fallback_notified", true)
    notify(
        "Markdown Tree-sitter parsers are unavailable; using scanner fallback",
        vim.log.levels.WARN
    )
end

function M.wrap_links(opts)
    opts = opts or {}
    local config = config_module.get().links
    if not config.enabled then
        return nil, "link wrapping is disabled"
    end
    local bufnr = opts.bufnr or 0
    local result = links.wrap_buffer {
        bufnr = bufnr,
        line1 = opts.line1,
        line2 = opts.line2,
        treesitter = config.treesitter,
    }
    if result.used_fallback and config.treesitter ~= false then
        notify_fallback_once(bufnr, config)
    end
    return result
end

function M.cycle_task(opts)
    opts = opts or {}
    local config = config_module.get().tasks
    if not config.enabled then
        return nil, "task cycling is disabled"
    end
    opts.marker = opts.marker or config.marker
    return tasks.cycle_buffer(opts)
end

function M.format_selection(kind, opts)
    if not config_module.get().formatting.enabled then
        return nil, "visual formatting is disabled"
    end
    return formatter.apply(kind, opts)
end

function M.generate_pdf(opts)
    opts = opts or {}
    local config = config_module.get().pdf
    if not config.enabled then
        return nil, "PDF generation is disabled"
    end
    return pdf.generate(opts, config)
end

local function command_wrap_links(bufnr, args)
    local result, err = M.wrap_links {
        bufnr = bufnr,
        line1 = args.line1,
        line2 = args.line2,
    }
    if not result then
        notify(err, vim.log.levels.ERROR)
    elseif result.replacements == 0 then
        notify "no bare links found"
    else
        notify(
            ("wrapped %d bare link%s"):format(
                result.replacements,
                result.replacements == 1 and "" or "s"
            )
        )
    end
end

local function command_cycle_task(bufnr)
    local _, err = M.cycle_task { bufnr = bufnr }
    if err then
        notify(err, vim.log.levels.ERROR)
    end
end

local function command_pdf(bufnr)
    local _, err = M.generate_pdf {
        bufnr = bufnr,
        on_complete = function(result)
            if result.ok then
                notify("generated " .. result.output_path)
                return
            end
            local details = vim.trim(result.stderr .. "\n" .. result.stdout)
            if details == "" then
                details = "pandoc exited with code " .. result.code
            end
            notify("PDF generation failed: " .. details, vim.log.levels.ERROR)
        end,
    }
    if err then
        notify(err, vim.log.levels.ERROR)
    end
end

local function format_keymap(bufnr, kind)
    return function()
        local _, err = M.format_selection(kind, { bufnr = bufnr })
        if err then
            notify(err, vim.log.levels.WARN)
        end
    end
end

function M.attach(bufnr)
    bufnr = bufnr or 0
    if vim.bo[bufnr].filetype ~= "markdown" then
        return false
    end
    if state.attached[bufnr] then
        return true
    end
    local config = config_module.get()
    if config.links.enabled then
        create_command(bufnr, config.commands.wrap_links, function(args)
            command_wrap_links(bufnr, args)
        end, { range = "%", desc = "Wrap bare URLs and file paths" })
        create_keymap(bufnr, "n", config.keymaps.wrap_links, function()
            command_wrap_links(bufnr, {
                line1 = 1,
                line2 = vim.api.nvim_buf_line_count(bufnr),
            })
        end, "wrap bare URLs and file paths")
    end
    if config.tasks.enabled then
        create_command(bufnr, config.commands.cycle_task, function()
            command_cycle_task(bufnr)
        end, { desc = "Cycle the current Markdown task state" })
        create_keymap(bufnr, "n", config.keymaps.cycle_task, function()
            command_cycle_task(bufnr)
        end, "cycle the current Markdown task state")
    end
    if config.pdf.enabled then
        create_command(bufnr, config.commands.pdf, function()
            command_pdf(bufnr)
        end, {
            desc = "Generate a PDF next to the current Markdown file",
        })
        create_keymap(bufnr, "n", config.keymaps.pdf, function()
            command_pdf(bufnr)
        end, "generate a PDF")
    end
    if config.formatting.enabled then
        for _, spec in ipairs {
            { "italic", config.keymaps.italic, "format selection as italic" },
            { "bold", config.keymaps.bold, "format selection as bold" },
            { "code", config.keymaps.code, "format selection as inline code" },
            { "link", config.keymaps.link, "format selection as a link" },
        } do
            create_keymap(
                bufnr,
                "x",
                spec[2],
                format_keymap(bufnr, spec[1]),
                spec[3]
            )
        end
    end
    state.attached[bufnr] = true
    return true
end

function M.setup(opts)
    cleanup()
    local config = config_module.resolve(opts)
    state.augroup =
        vim.api.nvim_create_augroup("markdown-tools", { clear = true })
    vim.api.nvim_create_autocmd("FileType", {
        group = state.augroup,
        pattern = "markdown",
        callback = function(event)
            M.attach(event.buf)
        end,
    })
    for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
        if
            vim.api.nvim_buf_is_loaded(bufnr)
            and vim.bo[bufnr].filetype == "markdown"
        then
            M.attach(bufnr)
        end
    end
    return config
end

M.links = links
M.tasks = tasks

return M
