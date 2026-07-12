local M = {}

local tests = {}
local stack = {}
local hook_stack = {}
local native_assert = _G.assert

local function reset_hooks()
    hook_stack = {
        {
            before_each = {},
            after_each = {},
        },
    }
end

reset_hooks()

local function collect_hooks(kind)
    local result = {}
    for _, hooks in ipairs(hook_stack) do
        for _, callback in ipairs(hooks[kind]) do
            result[#result + 1] = callback
        end
    end
    return result
end

local function full_name(name)
    local parts = vim.deepcopy(stack)
    parts[#parts + 1] = name
    return table.concat(parts, " ")
end

function _G.describe(name, callback)
    stack[#stack + 1] = name
    hook_stack[#hook_stack + 1] = {
        before_each = {},
        after_each = {},
    }
    local ok, err = xpcall(callback, debug.traceback)
    hook_stack[#hook_stack] = nil
    stack[#stack] = nil
    if not ok then
        error(err, 0)
    end
end

function _G.it(name, callback)
    tests[#tests + 1] = {
        name = full_name(name),
        run = callback,
        before_each = collect_hooks "before_each",
        after_each = collect_hooks "after_each",
    }
end

function _G.before_each(callback)
    local hooks = hook_stack[#hook_stack]
    hooks.before_each[#hooks.before_each + 1] = callback
end

function _G.after_each(callback)
    local hooks = hook_stack[#hook_stack]
    hooks.after_each[#hooks.after_each + 1] = callback
end

local function fail(message, level)
    error(message, (level or 1) + 1)
end

local function inspect(value)
    return vim.inspect(value)
end

local function equal(expected, actual, message)
    if expected ~= actual then
        fail(
            message
                or (
                    "expected "
                    .. inspect(expected)
                    .. ", got "
                    .. inspect(actual)
                ),
            2
        )
    end
end

local function not_equal(expected, actual, message)
    if expected == actual then
        fail(
            message or ("expected value not to equal " .. inspect(expected)),
            2
        )
    end
end

local function same(expected, actual, message)
    if not vim.deep_equal(expected, actual) then
        fail(
            message
                or (
                    "expected "
                    .. inspect(expected)
                    .. ", got "
                    .. inspect(actual)
                ),
            2
        )
    end
end

local function truthy(value, message)
    if not value then
        fail(message or ("expected truthy value, got " .. inspect(value)), 2)
    end
end

local function falsy(value, message)
    if value then
        fail(message or ("expected falsy value, got " .. inspect(value)), 2)
    end
end

local function is_true(value, message)
    if value ~= true then
        fail(message or ("expected true, got " .. inspect(value)), 2)
    end
end

local function is_false(value, message)
    if value ~= false then
        fail(message or ("expected false, got " .. inspect(value)), 2)
    end
end

local function is_nil(value, message)
    if value ~= nil then
        fail(message or ("expected nil, got " .. inspect(value)), 2)
    end
end

local function is_not_nil(value, message)
    if value == nil then
        fail(message or "expected non-nil value, got nil", 2)
    end
end

local function has_error(callback, expected)
    local ok, err = pcall(callback)
    if ok then
        fail("expected function to error", 2)
    end
    if expected and not tostring(err):find(expected, 1, true) then
        fail(
            ("expected error containing %s, got %s"):format(
                inspect(expected),
                inspect(err)
            ),
            2
        )
    end
    return err
end

local assertions = setmetatable({}, {
    __call = function(_, value, message)
        return native_assert(value, message)
    end,
})

assertions.equal = equal
assertions.equals = equal
assertions.not_equal = not_equal
assertions.same = same
assertions.truthy = truthy
assertions.falsy = falsy
assertions.True = is_true
assertions.False = is_false
assertions.Falsy = falsy
assertions.is_true = is_true
assertions.is_false = is_false
assertions.is_nil = is_nil
assertions.is_not_nil = is_not_nil
assertions.has_error = has_error
assertions.number = function(value)
    if type(value) ~= "number" then
        fail("expected number, got " .. inspect(value), 2)
    end
end
assertions.are = assertions
assertions.is = assertions
assertions.are_not = {
    equal = not_equal,
    equals = not_equal,
    same = function(expected, actual, message)
        if vim.deep_equal(expected, actual) then
            fail(
                message or ("expected value not to equal " .. inspect(expected)),
                2
            )
        end
    end,
}
_G.assert = assertions

local function add_legacy_suite(file, suite, failures)
    if suite == nil then
        return
    end
    if type(suite) ~= "table" then
        failures[#failures + 1] = {
            name = "load " .. file,
            err = "spec must register tests or return a table of test cases",
        }
        return
    end
    for _, test in ipairs(suite) do
        if
            type(test) ~= "table"
            or type(test.name) ~= "string"
            or type(test.run) ~= "function"
        then
            failures[#failures + 1] = {
                name = "load " .. file,
                err = "legacy test cases require string name and function run",
            }
        else
            tests[#tests + 1] = {
                name = test.name,
                run = test.run,
                before_each = {},
                after_each = {},
            }
        end
    end
end

local function discover_files()
    local seen = {}
    local result = {}
    for _, pattern in ipairs { "lua/**/*_spec.lua", "tests/**/*_spec.lua" } do
        for _, file in
            ipairs(vim.fn.globpath(vim.fn.getcwd(), pattern, true, true))
        do
            if not seen[file] then
                seen[file] = true
                result[#result + 1] = file
            end
        end
    end
    table.sort(result)
    return result
end

local function normalize_files(files)
    if files == nil then
        return discover_files()
    end
    local result = {}
    for _, file in ipairs(files) do
        result[#result + 1] = vim.fn.fnamemodify(file, ":p")
    end
    table.sort(result)
    return result
end

local function load_files(files)
    local failures = {}
    for _, file in ipairs(files) do
        reset_hooks()
        local ok, suite = xpcall(function()
            return dofile(file)
        end, debug.traceback)
        if not ok then
            failures[#failures + 1] = {
                name = "load " .. file,
                err = suite,
            }
        else
            add_legacy_suite(file, suite, failures)
        end
    end
    return failures
end

local function run_test(test)
    local ok = true
    local err
    for _, callback in ipairs(test.before_each) do
        local hook_ok, hook_err = xpcall(callback, debug.traceback)
        if not hook_ok then
            ok = false
            err = hook_err
            break
        end
    end
    if ok then
        ok, err = xpcall(test.run, debug.traceback)
    end
    for index = #test.after_each, 1, -1 do
        local hook_ok, hook_err =
            xpcall(test.after_each[index], debug.traceback)
        if not hook_ok then
            if ok then
                ok = false
                err = hook_err
            else
                err = err .. "\n" .. hook_err
            end
        end
    end
    return ok, err
end

function M.run(opts)
    opts = opts or {}
    tests = {}
    stack = {}
    reset_hooks()
    local failures = load_files(normalize_files(opts.files))
    for _, failure in ipairs(failures) do
        print("not ok - " .. failure.name)
        print(failure.err)
    end
    for _, test in ipairs(tests) do
        local ok, err = run_test(test)
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
