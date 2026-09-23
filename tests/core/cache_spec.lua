local Cache    = require("lazy.core.cache")
local Helpers  = require("helpers")
local MiniTest = require("mini.test")

describe("cache find", function()
    it(
        "returns only the first match by default, all matches with opts.all",
        function()
            local paths = {
                Helpers.path("cache_all_a"),
                Helpers.path("cache_all_b"),
            }
            Helpers.fs_create(
                { "cache_all_a/lua/foo.lua", "cache_all_b/lua/foo.lua" }
            )

            local first = Cache.find("foo", { rtp = false, paths = paths })
            assert.equal(1, #first)

            local all = Cache.find(
                "foo",
                { rtp = false, all = true, paths = paths }
            )
            assert.equal(2, #all)

            Helpers.fs_rm("cache_all_a")
            Helpers.fs_rm("cache_all_b")
        end
    )

    it("enumerates top-level modules for topmod == '*'", function()
        local path = Helpers.path("cache_star")
        Helpers.fs_create(
            { "cache_star/lua/mod1.lua", "cache_star/lua/mod2.lua" }
        )

        local all   = Cache.find(
            "*",
            { rtp = false, all = true, paths = { path } }
        )
        local names = vim.tbl_map(function(r)
            return r.modname
        end, all)
        table.sort(names)
        assert.same({ "mod1", "mod2" }, names)

        Helpers.fs_rm("cache_star")
    end)

    it(
        "prefers /init.lua over a flat .lua for single-segment modnames",
        function()
            local path = Helpers.path("cache_order_single")
            Helpers.fs_create({
                "cache_order_single/lua/dirmod/init.lua",
                "cache_order_single/lua/dirmod.lua",
            })

            local results = Cache.find(
                "dirmod",
                { rtp = false, paths = { path } }
            )
            assert.equal(1, #results)
            assert(
                results[1].modpath:find("init.lua", 1, true) ~= nil,
                results[1].modpath
            )

            Helpers.fs_rm("cache_order_single")
        end
    )

    it("prefers a flat .lua over /init.lua for dotted modnames", function()
        local path = Helpers.path("cache_order_dotted")
        Helpers.fs_create({
            "cache_order_dotted/lua/pkg/dirmod.lua",
            "cache_order_dotted/lua/pkg/dirmod/init.lua",
        })

        local results = Cache.find(
            "pkg.dirmod",
            { rtp = false, paths = { path } }
        )
        assert.equal(1, #results)
        assert(
            results[1].modpath:sub(-4) == ".lua"
                and not results[1].modpath:find("init.lua", 1, true),
            results[1].modpath
        )

        Helpers.fs_rm("cache_order_dotted")
    end)

    it(
        "respects opts.patterns, skipping the default OPTIM patterns",
        function()
            local path = Helpers.path("cache_patterns")
            Helpers.fs_create({ "cache_patterns/lua/custommod/custom.lua" })

            local results = Cache.find("custommod", {
                rtp = false,
                patterns = { "/custom.lua" },
                paths = { path },
            })
            assert.equal(1, #results)

            Helpers.fs_rm("cache_patterns")
        end
    )

    it("bumps the not_found stat when nothing matches", function()
        local path = Helpers.path("cache_missing")
        Helpers.fs_create({ "cache_missing/lua/present.lua" })

        local before = Cache._inspect()
            .find
            .not_found
        Cache.find("definitely_missing_xyz", { rtp = false, paths = { path } })
        local after = Cache._inspect()
            .find
            .not_found
        assert.equal(before + 1, after)

        Helpers.fs_rm("cache_missing")
    end)

    it(
        "M.reset(path) invalidates the stale top-level module index for that path",
        function()
            local path = Helpers.path("cache_reset_one")
            vim.fn.mkdir(path .. "/lua", "p")

            assert.equal(
                0,
                #Cache.find("newmod", { rtp = false, paths = { path } })
            )
            Helpers.fs_create({ "cache_reset_one/lua/newmod.lua" })
            assert.equal(
                0,
                #Cache.find("newmod", { rtp = false, paths = { path } }),
                "should still be stale"
            )

            Cache.reset(path)
            assert.equal(
                1,
                #Cache.find("newmod", { rtp = false, paths = { path } })
            )

            Helpers.fs_rm("cache_reset_one")
        end
    )

    it("M.reset() with no path invalidates every indexed path", function()
        local path_a = Helpers.path("cache_reset_all_a")
        local path_b = Helpers.path("cache_reset_all_b")
        vim.fn.mkdir(path_a .. "/lua", "p")
        vim.fn.mkdir(path_b .. "/lua", "p")

        assert.equal(
            0,
            #Cache.find("newmod", { rtp = false, paths = { path_a } })
        )
        assert.equal(
            0,
            #Cache.find("newmod", { rtp = false, paths = { path_b } })
        )
        Helpers.fs_create({
            "cache_reset_all_a/lua/newmod.lua",
            "cache_reset_all_b/lua/newmod.lua",
        })

        Cache.reset()

        assert.equal(
            1,
            #Cache.find("newmod", { rtp = false, paths = { path_a } })
        )
        assert.equal(
            1,
            #Cache.find("newmod", { rtp = false, paths = { path_b } })
        )

        Helpers.fs_rm("cache_reset_all_a")
        Helpers.fs_rm("cache_reset_all_b")
    end)
end)

describe("cache enable/disable", function()
    it("toggles the experimental loader safely", function()
        -- lazy.nvim enables the cache loader on startup by default, so start
        -- from a known (disabled) state and restore whatever was there before.
        local was_enabled = Cache.enabled
        MiniTest.finally(function()
            if was_enabled then
                Cache.enable()
            else
                Cache.disable()
            end
        end)

        Cache.disable()
        assert.equal(false, Cache.enabled)
        -- selene: allow(global_usage)
        local disabled_loadfile = _G.loadfile

        Cache.enable()
        assert.equal(true, Cache.enabled)
        -- selene: allow(global_usage)
        assert(_G.loadfile ~= disabled_loadfile)
    end)
end)
