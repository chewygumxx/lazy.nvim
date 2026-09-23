local Mocks    = require("mocks")
local MiniTest = require("mini.test")
local Stats    = require("lazy.stats")

describe("stats", function()
    it("track() records the event's timestamp and returns it", function()
        local t = Stats.track("test-event")
        assert.equal(t, Stats._stats.times["test-event"])
        assert.is_true(type(t) == "number")
    end)

    it(
        "cputime() returns a non-negative number and records real_cputime",
        function()
            local t = Stats.cputime()
            assert.is_true(type(t) == "number" and t >= 0)
            assert.is_true(type(Stats._stats.real_cputime) == "boolean")
        end
    )

    it(
        "stats() counts total and loaded plugins from Config.plugins",
        function()
            local restore = Mocks.patch("lazy.core.config", {
                plugins = {
                    a = { name = "a", _ = { loaded = true } },
                    b = { name = "b", _ = { loaded = false } },
                    c = { name = "c", _ = {} },
                },
            })
            MiniTest.finally(restore)

            local stats = Stats.stats()
            assert.equal(3, stats.count)
            assert.equal(1, stats.loaded)
        end
    )

    it("stats() recomputes on every call rather than accumulating", function()
        local restore = Mocks.patch("lazy.core.config", {
            plugins = { a = { name = "a", _ = { loaded = true } } },
        })
        MiniTest.finally(restore)

        Stats.stats()
        local stats = Stats.stats()
        assert.equal(1, stats.count)
        assert.equal(1, stats.loaded)
    end)
end)
