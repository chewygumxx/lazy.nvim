local Loader   = require("lazy.core.loader")
local MiniTest = require("mini.test")
local Mocks    = require("mocks")

describe("loader _load", function()
    it("does not load an uninstalled plugin", function()
        local plugin = { name = "p1", _ = { installed = false } }
        Loader._load(plugin, {})
        assert.equal(nil, plugin._.loaded)
    end)

    it("skips when cond is false, unless forced", function()
        MiniTest.finally(Mocks.patch("lazy.core.handler", { did_setup = true }))
        local plugin = {
            name = "p2",
            dir = "/dev/null/p2",
            virtual = true,
            _ = {
                installed = true,
                cond = false,
            },
        }
        Loader._load(plugin, {})
        assert.equal(nil, plugin._.loaded)
        Loader._load(plugin, {}, { force = true })
        assert(plugin._.loaded ~= nil)
    end)

    it("recursively loads dependencies", function()
        MiniTest.finally(Mocks.patch("lazy.core.handler", { did_setup = true }))
        local dep    = {
            name = "dep1",
            dir = "/dev/null/dep1",
            virtual = true,
            _ = {
                installed = true,
            },
        }
        local plugin = {
            name = "p3",
            dir = "/dev/null/p3",
            virtual = true,
            dependencies = { "dep1" },
            _ = { installed = true },
        }
        MiniTest.finally(
            Mocks.patch("lazy.core.config", {
                plugins = {
                    dep1 = dep,
                    p3 = plugin,
                },
            })
        )
        Loader._load(plugin, {})
        assert(dep._.loaded ~= nil)
        assert(plugin._.loaded ~= nil)
    end)

    it("runs plugin.config via M.config", function()
        MiniTest.finally(Mocks.patch("lazy.core.handler", { did_setup = true }))
        local called = false
        local plugin = {
            name = "p4",
            dir = "/dev/null/p4",
            virtual = true,
            config = function()
                called = true
            end,
            _ = { installed = true },
        }
        Loader._load(plugin, {})
        assert(called)
    end)
end)

describe("loader reload", function()
    local function noop_handler()
        return Mocks.patch("lazy.core.handler", {
            did_setup = true,
            enable = function() end,
            disable = function() end,
        })
    end

    it("errors when the plugin name is not found", function()
        MiniTest.finally(Mocks.patch("lazy.core.config", { plugins = {} }))
        local expect = MiniTest.expect
        expect.error(function()
            Loader.reload("nonexistent")
        end, "not found")
    end)

    it("forces a lazy == false plugin to load", function()
        MiniTest.finally(noop_handler())
        local plugin = {
            name = "rp1",
            dir = "/dev/null/rp1",
            virtual = true,
            lazy = false,
            _ = {
                installed = true,
            },
        }
        MiniTest.finally(
            Mocks.patch("lazy.core.config", {
                plugins = {
                    rp1 = plugin,
                },
            })
        )
        Loader.reload(plugin)
        assert(plugin._.loaded ~= nil)
    end)

    it(
        "forces load when a VimEnter/UIEnter/VeryLazy event handler is registered",
        function()
            MiniTest.finally(noop_handler())
            local plugin = {
                name = "rp2",
                dir = "/dev/null/rp2",
                virtual = true,
                _ = {
                    installed = true,
                    handlers = { event = { x = { id = "VimEnter" } } },
                },
            }
            MiniTest.finally(
                Mocks.patch("lazy.core.config", {
                    plugins = {
                        rp2 = plugin,
                    },
                })
            )
            Loader.reload(plugin)
            assert(plugin._.loaded ~= nil)
        end
    )

    it("does not load when nothing forces it", function()
        MiniTest.finally(noop_handler())
        local plugin = {
            name = "rp3",
            dir = "/dev/null/rp3",
            virtual = true,
            _ = {
                installed = true,
            },
        }
        Loader.reload(plugin)
        assert.equal(nil, plugin._.loaded)
    end)
end)

describe("loader get_start_plugins", function()
    it(
        "sorts by priority descending, filtering loaded/non-start plugins",
        function()
            local low            = {
                name = "low",
                priority = 10,
                _ = {
                    rtp_loaded = true,
                },
            }
            local high           = {
                name = "high",
                priority = 100,
                _ = {
                    rtp_loaded = true,
                },
            }
            local already_loaded = {
                name = "loaded",
                priority = 200,
                _ = {
                    loaded = {},
                    rtp_loaded = true,
                },
            }
            local not_start      = {
                name = "notstart",
                _ = {
                    rtp_loaded = false,
                },
            }
            local lazy_false     = {
                name = "lazyfalse",
                priority = 50,
                lazy = false,
                _ = {
                    rtp_loaded = false,
                },
            }
            MiniTest.finally(
                Mocks.patch("lazy.core.config", {
                    plugins = {
                        low = low,
                        high = high,
                        loaded = already_loaded,
                        notstart = not_start,
                        lazyfalse = lazy_false,
                    },
                })
            )
            local start = Loader.get_start_plugins()
            local names = vim.tbl_map(function(p)
                return p.name
            end, start)
            assert.same({ "high", "lazyfalse", "low" }, names)
        end
    )
end)

---@param t table
---@return LazyPlugin
local function fake_plugin(t)
    return t --[[@as LazyPlugin]]
end

describe("loader get_main", function()
    it("returns plugin.main when explicitly set", function()
        assert.equal(
            "some.module",
            Loader.get_main(
                fake_plugin({
                    name = "gm1",
                    main = "some.module",
                })
            )
        )
    end)

    it("special-cases mini.* names, except mini.nvim itself", function()
        assert.equal(
            "mini.icons",
            Loader.get_main(
                fake_plugin({
                    name = "mini.icons",
                })
            )
        )
        assert.equal(
            nil,
            Loader.get_main(
                fake_plugin({
                    name = "mini.nvim",
                    dir = "/dev/null/mini.nvim",
                })
            )
        )
    end)

    it("returns nil when zero modules are found", function()
        MiniTest.finally(
            Mocks.patch("lazy.core.cache", {
                find = function()
                    return {}
                end,
            })
        )
        assert.equal(
            nil,
            Loader.get_main(
                fake_plugin({
                    name = "zero",
                    dir = "/dev/null/zero",
                })
            )
        )
    end)

    it("returns the module when exactly one is found", function()
        MiniTest.finally(
            Mocks.patch("lazy.core.cache", {
                find = function()
                    return { { modname = "onlymod" } }
                end,
            })
        )
        assert.equal(
            "onlymod",
            Loader.get_main(
                fake_plugin({
                    name = "onlymod",
                    dir = "/dev/null/onlymod",
                })
            )
        )
    end)

    it("returns nil with multiple candidates and no exact match", function()
        MiniTest.finally(
            Mocks.patch("lazy.core.cache", {
                find = function()
                    return { { modname = "modA" }, { modname = "modB" } }
                end,
            })
        )
        assert.equal(
            nil,
            Loader.get_main(
                fake_plugin({
                    name = "somename",
                    dir = "/dev/null/somename",
                })
            )
        )
    end)

    it(
        "short-circuits to an exact normalized-name match among multiple candidates",
        function()
            MiniTest.finally(
                Mocks.patch("lazy.core.cache", {
                    find = function()
                        return {
                            { modname = "other" },
                            { modname = "exactmatch" },
                        }
                    end,
                })
            )
            assert.equal(
                "exactmatch",
                Loader.get_main(
                    fake_plugin({
                        name = "exactmatch",
                        dir = "/dev/null/exactmatch",
                    })
                )
            )
        end
    )
end)
