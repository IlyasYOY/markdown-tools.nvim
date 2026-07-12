local M = {}

local jobs = {}

local function buffer_text(bufnr)
    return table.concat(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false), "\n")
        .. "\n"
end

local function default_output_path(input_path)
    return vim.fn.fnamemodify(input_path, ":r") .. ".pdf"
end

local function resolve_output_path(config, context)
    if not config.output_path then
        return default_output_path(context.input_path)
    end
    local ok, output = pcall(config.output_path, context)
    if not ok then
        return nil, "PDF output_path hook failed: " .. tostring(output)
    end
    if type(output) ~= "string" or output == "" then
        return nil, "PDF output_path hook must return a non-empty string"
    end
    return vim.fs.normalize(output)
end

local function preprocess(config, content, context)
    if not config.preprocess then
        return content
    end
    local ok, result = pcall(config.preprocess, content, context)
    if not ok then
        return nil, "PDF preprocess hook failed: " .. tostring(result)
    end
    if type(result) ~= "string" then
        return nil, "PDF preprocess hook must return a string"
    end
    return result
end

local function build_argv(config, output_path)
    local argv = {
        config.pandoc,
        "--from=gfm",
        "--to=pdf",
        "--standalone",
        "--pdf-engine=" .. config.typst,
        "--variable=linkcolor:005cc5",
        "--variable=filecolor:005cc5",
        "--variable=citecolor:005cc5",
    }
    if config.toc then
        vim.list_extend(argv, {
            "--toc",
            "--toc-depth=" .. tostring(config.toc_depth),
        })
    end
    vim.list_extend(argv, { "--resource-path=.", unpack(config.extra_args) })
    vim.list_extend(argv, { "--output", output_path, "-" })
    return argv
end

function M.generate(opts, config)
    opts = opts or {}
    local bufnr = opts.bufnr or 0
    local input_path = vim.api.nvim_buf_get_name(bufnr)
    if input_path == "" then
        return nil, "cannot generate a PDF for a buffer without a file path"
    end
    input_path = vim.fs.normalize(input_path)
    if vim.fn.executable(config.pandoc) == 0 then
        return nil, config.pandoc .. " is required to generate Markdown PDFs"
    end
    if vim.fn.executable(config.typst) == 0 then
        return nil, config.typst .. " is required to render Markdown PDFs"
    end

    local context = {
        bufnr = bufnr,
        input_path = input_path,
        cwd = vim.fs.dirname(input_path),
    }
    local output_path, output_err = resolve_output_path(config, context)
    if not output_path then
        return nil, output_err
    end
    context.output_path = output_path
    if jobs[output_path] then
        return nil, "a PDF job is already running for " .. output_path
    end

    local content, preprocess_err =
        preprocess(config, buffer_text(bufnr), context)
    if not content then
        return nil, preprocess_err
    end

    local argv = build_argv(config, output_path)
    local handle
    handle = vim.system({ unpack(argv) }, {
        cwd = context.cwd,
        stdin = content,
        text = true,
    }, function(completed)
        vim.schedule(function()
            jobs[output_path] = nil
            local result = {
                ok = completed.code == 0,
                code = completed.code,
                signal = completed.signal,
                stdout = completed.stdout or "",
                stderr = completed.stderr or "",
                output_path = output_path,
                argv = argv,
            }
            if opts.on_complete then
                opts.on_complete(result)
            end
        end)
    end)
    jobs[output_path] = handle
    return handle
end

function M._jobs()
    return jobs
end

return M
