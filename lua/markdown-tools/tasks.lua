local M = {}

local states = {
    line = "line",
    list = "list",
    unchecked = "unchecked",
    checked = "checked",
}

local function split_line(line)
    local indent, content = line:match "^(%s*)(.*)$"
    return indent or "", content or ""
end

function M.cycle_line(line, default_marker)
    default_marker = default_marker or "-"
    local indent, content = split_line(line)

    local marker, text = content:match "^([%-%+%*])%s+%[[xX]%]%s?(.*)$"
    if marker then
        return indent .. text, states.checked, states.line
    end

    marker, text = content:match "^([%-%+%*])%s+%[%s%]%s?(.*)$"
    if marker then
        return indent .. marker .. " [x] " .. text,
            states.unchecked,
            states.checked
    end

    marker, text = content:match "^([%-%+%*])%s+(.*)$"
    if not marker then
        marker = content:match "^([%-%+%*])$"
        text = marker and "" or nil
    end
    if marker then
        return indent .. marker .. " [ ] " .. text,
            states.list,
            states.unchecked
    end

    return indent .. default_marker .. " " .. content, states.line, states.list
end

function M.cycle_buffer(opts)
    opts = opts or {}
    local bufnr = opts.bufnr or 0
    local row = opts.row
        or (vim.api.nvim_win_get_cursor(opts.winid or 0)[1] - 1)
    local line = vim.api.nvim_buf_get_lines(bufnr, row, row + 1, false)[1]
    if line == nil then
        return nil, "row is outside the buffer"
    end

    local updated, from, to = M.cycle_line(line, opts.marker)
    vim.api.nvim_buf_set_lines(bufnr, row, row + 1, false, { updated })
    return { row = row, from = from, to = to, line = updated }
end

return M
