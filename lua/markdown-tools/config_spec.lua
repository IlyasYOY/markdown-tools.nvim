local config = require "markdown-tools.config"

describe("markdown-tools.config", function()
    before_each(function()
        config.resolve()
    end)

    after_each(function()
        config.resolve()
    end)

    it("returns independent defaults", function()
        local first = config.defaults()
        first.tasks.marker = "+"
        assert.equal("-", config.defaults().tasks.marker)
    end)

    it("normalizes feature and registration shorthands", function()
        local resolved = config.resolve {
            links = false,
            commands = false,
            keymaps = false,
        }
        assert.is_false(resolved.links.enabled)
        assert.is_false(resolved.commands.wrap_links)
        assert.is_false(resolved.commands.cycle_task)
        assert.is_false(resolved.commands.pdf)
        assert.is_false(resolved.keymaps.link)
    end)

    it("rejects invalid configuration", function()
        assert.has_error(function()
            config.resolve { tasks = { marker = ">" } }
        end, "tasks.marker")
        assert.has_error(function()
            config.resolve { links = { treesitter = "always" } }
        end, "links.treesitter")
        assert.has_error(function()
            config.resolve { pdf = { extra_args = "not-a-list" } }
        end, "pdf.extra_args")
    end)
end)
