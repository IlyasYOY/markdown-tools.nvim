local M = {}

local function add_range(ranges, start_col, end_col)
    if start_col <= end_col then
        ranges[#ranges + 1] = { start_col, end_col }
    end
end

local function merge_ranges(ranges)
    table.sort(ranges, function(left, right)
        if left[1] == right[1] then
            return left[2] < right[2]
        end
        return left[1] < right[1]
    end)

    local merged = {}
    for _, range in ipairs(ranges) do
        local previous = merged[#merged]
        if not previous or range[1] > previous[2] + 1 then
            merged[#merged + 1] = { range[1], range[2] }
        else
            previous[2] = math.max(previous[2], range[2])
        end
    end
    return merged
end

local function add_line_range(ranges_by_line, line_idx, start_col, end_col)
    ranges_by_line[line_idx] = ranges_by_line[line_idx] or {}
    add_range(ranges_by_line[line_idx], start_col, end_col)
end

local function merge_ranges_by_line(...)
    local result = {}
    for _, ranges_by_line in ipairs { ... } do
        if ranges_by_line then
            for line_idx, ranges in pairs(ranges_by_line) do
                for _, range in ipairs(ranges) do
                    add_line_range(result, line_idx, range[1], range[2])
                end
            end
        end
    end
    for line_idx, ranges in pairs(result) do
        result[line_idx] = merge_ranges(ranges)
    end
    return result
end

local function full_line_range(line)
    return { { 1, math.max(#line, 1) } }
end

local function collect_frontmatter(lines)
    local result = {}
    if not lines[1] or not lines[1]:match "^%-%-%-%s*$" then
        return result
    end
    for idx, line in ipairs(lines) do
        result[idx] = full_line_range(line)
        if
            idx > 1 and (line:match "^%-%-%-%s*$" or line:match "^%.%.%.%s*$")
        then
            break
        end
    end
    return result
end

local function fence_marker(line)
    local indent, marker = line:match "^(%s*)([`~]+)"
    if not marker or #indent > 3 or #marker < 3 then
        return nil
    end
    return marker:sub(1, 1), #marker
end

local function collect_fences(lines)
    local result = {}
    local active_marker
    local active_length
    for idx, line in ipairs(lines) do
        local marker, length = fence_marker(line)
        if active_marker then
            result[idx] = full_line_range(line)
            if marker == active_marker and length >= active_length then
                active_marker = nil
                active_length = nil
            end
        elseif marker then
            result[idx] = full_line_range(line)
            active_marker = marker
            active_length = length
        end
    end
    return result
end

local function find_unescaped(text, needle, init)
    local idx = init
    while true do
        local found = text:find(needle, idx, true)
        if not found then
            return nil
        end
        local slashes = 0
        local before = found - 1
        while before > 0 and text:sub(before, before) == "\\" do
            slashes = slashes + 1
            before = before - 1
        end
        if slashes % 2 == 0 then
            return found
        end
        idx = found + 1
    end
end

local function find_balanced(text, start_col, opening, closing)
    local depth = 0
    for idx = start_col, #text do
        local char = text:sub(idx, idx)
        if char == opening and find_unescaped(text, opening, idx) == idx then
            depth = depth + 1
        elseif
            char == closing and find_unescaped(text, closing, idx) == idx
        then
            depth = depth - 1
            if depth == 0 then
                return idx
            end
        end
    end
    return nil
end

local function collect_code_spans(line, ranges)
    local idx = 1
    while idx <= #line do
        local start_col, end_col = line:find("`+", idx)
        if not start_col then
            return
        end
        local ticks = line:sub(start_col, end_col)
        local close_start, close_end = line:find(ticks, end_col + 1, true)
        if not close_start then
            return
        end
        add_range(ranges, start_col, close_end)
        idx = close_end + 1
    end
end

local function collect_angle_links(line, ranges)
    local idx = 1
    while idx <= #line do
        local start_col, end_col, value = line:find("<([^%s<>]+)>", idx)
        if not start_col then
            return
        end
        if
            value:match "^[%a][%w+%.%-]*:"
            or value:match "^https?://"
            or value:match "^/"
            or value:match "^%.%./"
            or value:match "^%./"
            or value:match "^~/"
        then
            add_range(ranges, start_col, end_col)
        end
        idx = end_col + 1
    end
end

local function collect_link_definitions(line, ranges, definitions)
    local start_col, label = line:match "^()%s*%[([^%]]+)%]:"
    if not start_col then
        return
    end
    definitions[label:lower():gsub("%s+", " ")] = true
    add_range(ranges, 1, math.max(#line, 1))
end

local function collect_markdown_links(line, ranges, definitions)
    local idx = 1
    while idx <= #line do
        local image_start = line:find("![", idx, true)
        local link_start = line:find("[", idx, true)
        local start_col = image_start
        local bracket_start = image_start and image_start + 1 or nil
        if link_start and (not start_col or link_start < start_col) then
            start_col = link_start
            bracket_start = link_start
        end
        if not start_col then
            return
        end

        local label_end = find_balanced(line, bracket_start, "[", "]")
        if not label_end then
            return
        end
        local end_col
        local next_char = line:sub(label_end + 1, label_end + 1)
        if next_char == "(" then
            end_col = find_balanced(line, label_end + 1, "(", ")")
        elseif next_char == "[" then
            end_col = find_balanced(line, label_end + 1, "[", "]")
        else
            local label = line:sub(bracket_start + 1, label_end - 1)
                :lower()
                :gsub("%s+", " ")
            if definitions[label] then
                end_col = label_end
            end
        end

        if end_col then
            add_range(ranges, start_col, end_col)
            idx = end_col + 1
        else
            idx = label_end + 1
        end
    end
end

local function collect_scanner_ranges(lines)
    local result =
        merge_ranges_by_line(collect_frontmatter(lines), collect_fences(lines))
    local definitions = {}
    for idx, line in ipairs(lines) do
        result[idx] = result[idx] or {}
        collect_link_definitions(line, result[idx], definitions)
    end
    for idx, line in ipairs(lines) do
        local ranges = result[idx] or {}
        collect_code_spans(line, ranges)
        collect_angle_links(line, ranges)
        collect_markdown_links(line, ranges, definitions)
        result[idx] = merge_ranges(ranges)
    end
    return result
end

local protected_types = {
    code_span = true,
    collapsed_reference_link = true,
    email_autolink = true,
    fenced_code_block = true,
    full_reference_link = true,
    image = true,
    image_description = true,
    indented_code_block = true,
    inline_link = true,
    shortcut_link = true,
    uri_autolink = true,
}

local function add_node_ranges(ranges_by_line, node)
    local start_row, start_col, end_row, end_col = node:range()
    for row = start_row, end_row do
        local range_start = row == start_row and start_col + 1 or 1
        local range_end = row == end_row and end_col or math.huge
        add_line_range(ranges_by_line, row + 1, range_start, range_end)
    end
end

local function collect_parser_ranges(bufnr, language)
    local ok, parser = pcall(vim.treesitter.get_parser, bufnr, language)
    if not ok or not parser then
        return nil
    end
    local parse_ok, trees = pcall(parser.parse, parser)
    if not parse_ok then
        return nil
    end
    local result = {}
    local function walk(node)
        if protected_types[node:type()] then
            add_node_ranges(result, node)
            return
        end
        for child in node:iter_children() do
            walk(child)
        end
    end
    for _, tree in ipairs(trees) do
        walk(tree:root())
    end
    return result
end

local function collect_treesitter_ranges(bufnr)
    local markdown = collect_parser_ranges(bufnr, "markdown")
    local inline = collect_parser_ranges(bufnr, "markdown_inline")
    if not markdown or not inline then
        return nil
    end
    return merge_ranges_by_line(markdown, inline)
end

local function trim_unmatched_closers(token)
    local trailing = ""
    local pairs = { [")"] = "(", ["]"] = "[", ["}"] = "{" }
    while true do
        local closer = token:sub(-1)
        local opener = pairs[closer]
        if not opener then
            break
        end
        local _, open_count = token:gsub("%" .. opener, "")
        local _, close_count = token:gsub("%" .. closer, "")
        if close_count <= open_count then
            break
        end
        token = token:sub(1, -2)
        trailing = closer .. trailing
    end
    return token, trailing
end

local function split_trailing_punctuation(token)
    local bare = token:gsub("[.,;:!?]+$", "")
    local trailing = token:sub(#bare + 1)
    local balanced, closers = trim_unmatched_closers(bare)
    return balanced, closers .. trailing
end

local function find_candidate(text, init)
    local best_start
    local best_end
    local best_type
    local function consider(pattern, kind)
        local start_col, end_col = text:find(pattern, init)
        if start_col and (not best_start or start_col < best_start) then
            best_start = start_col
            best_end = end_col
            best_type = kind
        end
    end
    consider("https?://[^%s<>\"']+", "url")
    consider("%.%./[%w%._~%-%+/%%@]+", "path")
    consider("%./[%w%._~%-%+/%%@]+", "path")
    consider("~/[%w%._~%-%+/%%@]+", "path")
    consider("/[%w%._~%-%+/%%@]+", "path")
    return best_start, best_end, best_type
end

local function wrap_text(text)
    local chunks = {}
    local replacements = 0
    local idx = 1
    while idx <= #text do
        local start_col, end_col, kind = find_candidate(text, idx)
        if not start_col then
            chunks[#chunks + 1] = text:sub(idx)
            break
        end
        chunks[#chunks + 1] = text:sub(idx, start_col - 1)
        local token = text:sub(start_col, end_col)
        local bare, trailing = split_trailing_punctuation(token)
        local previous = start_col > 1
                and text:sub(start_col - 1, start_col - 1)
            or ""
        local path_inside_word = kind == "path"
            and previous ~= ""
            and previous:match "[%w%]%)]"
        if bare == "" or path_inside_word then
            chunks[#chunks + 1] = token
        else
            chunks[#chunks + 1] = "<" .. bare .. ">" .. trailing
            replacements = replacements + 1
        end
        idx = end_col + 1
    end
    return table.concat(chunks), replacements
end

local function wrap_line(line, ranges)
    local chunks = {}
    local replacements = 0
    local next_col = 1
    for _, range in ipairs(ranges) do
        local range_start = math.max(range[1], 1)
        local range_end = math.min(range[2], #line)
        if next_col < range_start then
            local chunk, count = wrap_text(line:sub(next_col, range_start - 1))
            chunks[#chunks + 1] = chunk
            replacements = replacements + count
        end
        if range_end >= range_start then
            chunks[#chunks + 1] = line:sub(range_start, range_end)
            next_col = range_end + 1
        end
    end
    if next_col <= #line then
        local chunk, count = wrap_text(line:sub(next_col))
        chunks[#chunks + 1] = chunk
        replacements = replacements + count
    end
    return table.concat(chunks), replacements
end

function M.wrap_lines(lines, opts)
    opts = opts or {}
    local ranges = collect_scanner_ranges(lines)
    local used_fallback = false
    if opts.bufnr and opts.treesitter ~= false then
        local treesitter_ranges = collect_treesitter_ranges(opts.bufnr)
        if treesitter_ranges then
            ranges = merge_ranges_by_line(ranges, treesitter_ranges)
        else
            used_fallback = true
        end
    end

    local first = opts.line1 or 1
    local last = opts.line2 or #lines
    local updated = vim.deepcopy(lines)
    local replacements = 0
    for idx = first, math.min(last, #lines) do
        local line, count = wrap_line(lines[idx], ranges[idx] or {})
        updated[idx] = line
        replacements = replacements + count
    end
    return updated,
        { replacements = replacements, used_fallback = used_fallback }
end

function M.wrap_buffer(opts)
    opts = opts or {}
    local bufnr = opts.bufnr or 0
    local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
    local updated, result = M.wrap_lines(lines, {
        bufnr = bufnr,
        treesitter = opts.treesitter,
        line1 = opts.line1,
        line2 = opts.line2,
    })
    if result.replacements > 0 then
        vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, updated)
    end
    return result
end

return M
