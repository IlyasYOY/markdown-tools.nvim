local M = {}

local function files()
    local result =
        vim.fn.globpath(vim.fn.getcwd(), "tests/*_spec.lua", true, true)
    table.sort(result)
    return result
end

function M.run(opts)
    opts = opts or {}
    local tests = {}
    local failures = {}
    for _, file in ipairs(files()) do
        local ok, suite = xpcall(function()
            return dofile(file)
        end, debug.traceback)
        if not ok then
            failures[#failures + 1] = { name = "load " .. file, err = suite }
        else
            vim.list_extend(tests, suite)
        end
    end
    for _, test in ipairs(tests) do
        local ok, err = xpcall(test.run, debug.traceback)
        if ok then
            if opts.verbose then
                print("ok - " .. test.name)
            end
        else
            failures[#failures + 1] = { name = test.name, err = err }
            print("not ok - " .. test.name)
            print(err)
        end
    end
    print(("%d test(s) run"):format(#tests))
    if #failures > 0 then
        print(("%d test(s) failed"):format(#failures))
        vim.cmd "cquit 1"
    end
end

return M
