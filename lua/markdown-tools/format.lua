local M = {}

local delimiters = {
    italic = { "*", "*" },
    bold = { "**", "**" },
    code = { "`", "`" },
}

local function ordered_positions(first, second)
    if
        first[1] < second[1]
        or (first[1] == second[1] and first[2] <= second[2])
    then
        return first, second
    end
    return second, first
end

local function visual_range(bufnr)
    local mode = vim.fn.mode()
    local anchor = vim.fn.getpos "v"
    local cursor = vim.api.nvim_win_get_cursor(0)
    local first, last = ordered_positions(
        { anchor[2] - 1, anchor[3] - 1 },
        { cursor[1] - 1, cursor[2] }
    )
    if mode == "V" then
        first[2] = 0
        local line = vim.api.nvim_buf_get_lines(
            bufnr,
            last[1],
            last[1] + 1,
            false
        )[1] or ""
        last[2] = #line - 1
    end
    return {
        start_row = first[1],
        start_col = math.max(first[2], 0),
        end_row = last[1],
        end_col = math.max(last[2] + 1, 0),
    }
end

local function get_text(bufnr, range)
    return vim.api.nvim_buf_get_text(
        bufnr,
        range.start_row,
        range.start_col,
        range.end_row,
        range.end_col,
        {}
    )
end

local function replace_text(bufnr, range, original, prefix, suffix)
    if not vim.api.nvim_buf_is_valid(bufnr) then
        return nil, "buffer is no longer valid"
    end
    if not vim.deep_equal(get_text(bufnr, range), original) then
        return nil, "selection changed while waiting for input"
    end
    local replacement = vim.deepcopy(original)
    replacement[1] = prefix .. replacement[1]
    replacement[#replacement] = replacement[#replacement] .. suffix
    vim.api.nvim_buf_set_text(
        bufnr,
        range.start_row,
        range.start_col,
        range.end_row,
        range.end_col,
        replacement
    )
    return true
end

function M.apply(kind, opts)
    opts = opts or {}
    local bufnr = opts.bufnr or 0
    local range = opts.range or visual_range(bufnr)
    local original = get_text(bufnr, range)
    if #original == 0 then
        return nil, "selection is empty"
    end

    if kind ~= "link" then
        local pair = delimiters[kind]
        if not pair then
            return nil, "unknown formatting kind: " .. tostring(kind)
        end
        return replace_text(bufnr, range, original, pair[1], pair[2])
    end

    local function apply_target(target)
        if target == nil or target == "" then
            return
        end
        local ok, err =
            replace_text(bufnr, range, original, "[", "](" .. target .. ")")
        if not ok then
            vim.notify("markdown-tools: " .. err, vim.log.levels.WARN)
        end
        if opts.on_complete then
            opts.on_complete(ok, err)
        end
    end

    if opts.target ~= nil then
        apply_target(opts.target)
        return true
    end

    vim.ui.input({
        prompt = "Markdown link target: ",
        default = vim.fn.getreg "+",
    }, apply_target)
    return true
end

return M
