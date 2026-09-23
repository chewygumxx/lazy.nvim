local Helpers = require("helpers")
local Ft      = require("lazy.core.handler.ft")
local Mocks   = require("mocks")

describe("handler.ft", function()
    describe("_parse()", function()
        it("wraps a filetype string into a FileType LazyEvent", function()
            assert.same(
                { id = "lua", event = "FileType", pattern = "lua" },
                Ft:_parse("lua")
            )
        end)
    end)

    describe("add()", function()
        it(
            "delegates to super.add() and triggers ftdetect when " .. "plugin.ft is set",
            function()
                local super_called_with
                local self    = {
                    super = {
                        add = function(_self, plugin)
                            super_called_with = plugin
                        end,
                    },
                }
                local ftdetect_dir
                local restore = Mocks.patch("lazy.core.loader", {
                    ftdetect = function(dir)
                        ftdetect_dir = dir
                    end,
                })
                local plugin  = Helpers.plugin({ dir = "/x", ft = { "lua" } })

                Ft.add(self, plugin)
                restore()

                assert.equal(plugin, super_called_with)
                assert.equal("/x", ftdetect_dir)
            end
        )

        it(
            "delegates to super.add() but skips ftdetect when plugin.ft " .. "is unset",
            function()
                local super_called_with
                local self    = {
                    super = {
                        add = function(_self, plugin)
                            super_called_with = plugin
                        end,
                    },
                }
                local restore = Mocks.patch("lazy.core.loader", {
                    ftdetect = function()
                        error("ftdetect should not have been called")
                    end,
                })
                local plugin  = Helpers.plugin({ dir = "/x" })

                Ft.add(self, plugin)
                restore()

                assert.equal(plugin, super_called_with)
            end
        )
    end)
end)
