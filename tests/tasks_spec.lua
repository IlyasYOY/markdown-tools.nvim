local tasks = require "markdown-tools.tasks"

local function transition(input, expected, from, to, marker)
    local actual, actual_from, actual_to = tasks.cycle_line(input, marker)
    assert(actual == expected, ("expected %q, got %q"):format(expected, actual))
    assert(
        actual_from == from,
        ("expected state %s, got %s"):format(from, actual_from)
    )
    assert(actual_to == to, ("expected state %s, got %s"):format(to, actual_to))
end

return {
    {
        name = "cycles a line through list and task states",
        run = function()
            transition("write docs", "- write docs", "line", "list")
            transition("- write docs", "- [ ] write docs", "list", "unchecked")
            transition(
                "- [ ] write docs",
                "- [x] write docs",
                "unchecked",
                "checked"
            )
            transition("- [x] write docs", "write docs", "checked", "line")
        end,
    },
    {
        name = "preserves indentation and existing unordered markers",
        run = function()
            transition("    * nested", "    * [ ] nested", "list", "unchecked")
            transition(
                "  + [ ] nested",
                "  + [x] nested",
                "unchecked",
                "checked"
            )
            transition("\t* [X] nested", "\tnested", "checked", "line")
        end,
    },
    {
        name = "uses the configured marker for plain and empty lines",
        run = function()
            transition("  text", "  + text", "line", "list", "+")
            transition("  ", "  - ", "line", "list")
            transition("-", "- [ ] ", "list", "unchecked")
        end,
    },
}
