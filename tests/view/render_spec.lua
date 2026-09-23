---@diagnostic disable: missing-fields, need-check-nil
-- Only `M:ms()` and `M.list_icon()` are covered here. The rest of
-- lua/lazy/view/render.lua drives a real floating window against live
-- plugin/task state, which is UI orchestration better suited to manual or
-- integration testing than unit specs.
local Config = require("lazy.core.config")
local Render = require("lazy.view.render")

describe("view.render", function()
    describe("ms()", function()
        it("converts nanoseconds to a rounded millisecond string", function()
            assert.equal("1.5ms", Render.ms({}, 1.5 * 1e6))
        end)

        it("rounds to the given precision", function()
            assert.equal("2ms", Render.ms({}, 1.5 * 1e6, 0))
        end)

        it("defaults precision to 2 decimal places", function()
            assert.equal("1.23ms", Render.ms({}, 1.234 * 1e6))
        end)
    end)

    describe("list_icon()", function()
        it("cycles through ui.icons.list by depth, 1-indexed", function()
            local symbols = Config.options.ui.icons.list
            assert.equal(symbols[1], Render.list_icon(1))
            assert.equal(symbols[2], Render.list_icon(2))
        end)

        it("wraps back to the first symbol past the list length", function()
            local symbols = Config.options.ui.icons.list
            assert.equal(symbols[1], Render.list_icon(1 + #symbols))
        end)
    end)
end)
