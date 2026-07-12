local config = require "markdown-tools.config"
local health = require "markdown-tools.health"

local function capture_health()
    local reports = {}
    local captured = {}
    for _, level in ipairs { "start", "ok", "warn", "error", "info" } do
        captured[level] = function(message, advice)
            reports[#reports + 1] = {
                level = level,
                message = tostring(message),
                advice = advice,
            }
        end
    end
    return captured, reports
end

local function has_report(reports, level, text)
    for _, report in ipairs(reports) do
        if report.level == level and report.message:find(text, 1, true) then
            return true
        end
    end
    return false
end

describe("markdown-tools.health", function()
    local original_health

    before_each(function()
        original_health = vim.health
        config.resolve()
    end)

    after_each(function()
        vim.health = original_health
        config.resolve()
    end)

    it("reports optional PDF executables without failing", function()
        local captured, reports = capture_health()
        vim.health = captured
        config.resolve {
            pdf = {
                pandoc = "markdown-tools-missing-pandoc",
                typst = "markdown-tools-missing-typst",
            },
        }
        health.check()
        assert.is_true(has_report(reports, "start", "markdown-tools.nvim"))
        assert.is_true(
            has_report(reports, "warn", "PDF generation is unavailable")
        )
    end)

    it("reports available configured executables", function()
        local captured, reports = capture_health()
        vim.health = captured
        config.resolve { pdf = { pandoc = "true", typst = "true" } }
        health.check()
        assert.is_true(has_report(reports, "ok", "true is executable"))
    end)
end)
