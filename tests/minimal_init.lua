local function root(path)
    local source = debug.getinfo(1, "S").source:sub(2)
    local repo = vim.fn.fnamemodify(source, ":p:h:h")
    return path and vim.fs.joinpath(repo, path) or repo
end

local test_home = vim.env.MARKDOWN_TOOLS_TEST_HOME or root ".test-home"
vim.env.NVIM_LOG_FILE = vim.env.NVIM_LOG_FILE
    or vim.fs.joinpath(test_home, "nvim.log")
for name, suffix in pairs {
    XDG_CONFIG_HOME = "config",
    XDG_DATA_HOME = "data",
    XDG_CACHE_HOME = "cache",
    XDG_STATE_HOME = "state",
} do
    vim.env[name] = vim.fs.joinpath(test_home, suffix)
    vim.fn.mkdir(vim.env[name], "p")
end

vim.g.maplocalleader = ","
vim.opt.runtimepath:prepend(root())
vim.opt.shadafile = "NONE"
vim.opt.swapfile = false
vim.opt.undofile = false
package.path = root "?.lua" .. ";" .. root "?/init.lua" .. ";" .. package.path
vim.cmd.runtime "plugin/markdown-tools.lua"
