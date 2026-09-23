local Checker  = require("lazy.manage.checker")
local Mocks    = require("mocks")
local MiniTest = require("mini.test")

describe("checker", function()
    before_each(function()
        -- M.updated / M.reported are module-level singleton state.
        Checker.updated  = {}
        Checker.reported = {}
    end)

    describe("fast_check()", function()
        local plugins = {
            outdated = {
                name = "outdated",
                dir = "/outdated",
                _ = { installed = true },
            },
            current = {
                name = "current",
                dir = "/current",
                _ = { installed = true },
            },
            pinned = {
                name = "pinned",
                dir = "/pinned",
                pin = true,
                _ = { installed = true },
            },
            local_plugin = {
                name = "local_plugin",
                dir = "/local",
                _ = { installed = true, is_local = true },
            },
            not_installed = {
                name = "not_installed",
                dir = "/gone",
                _ = { installed = false },
            },
        }

        local restore_config, restore_git
        before_each(function()
            for _, p in pairs(plugins) do
                p._.updates = nil
            end
            restore_config = Mocks.patch("lazy.core.config", {
                plugins = plugins,
            })
            restore_git    = Mocks.patch("lazy.manage.git", {
                info = function(dir)
                    return ({
                        ["/outdated"] = { commit = "aaa0000" },
                        ["/current"] = { commit = "ccc1234" },
                        ["/pinned"] = { commit = "aaa0000" },
                        ["/local"] = { commit = "aaa0000" },
                    })[dir]
                end,
                get_target = function(plugin)
                    return ({
                        ["/outdated"] = { commit = "bbb0000" },
                        ["/current"] = { commit = "ccc1234xyz" },
                        ["/pinned"] = { commit = "bbb0000" },
                        ["/local"] = { commit = "bbb0000" },
                    })[plugin.dir]
                end,
            })
        end)
        -- MiniTest.finally() drains at the end of the *step* it was called
        -- from, so restores registered inside before_each would already run
        -- before the test body does; after_each is the hook that actually
        -- runs once the test body has finished.
        after_each(function()
            restore_config()
            restore_git()
        end)

        it(
            "marks only installed, non-pinned, non-local plugins as outdated",
            function()
                Checker.fast_check({ report = false })

                assert(plugins.outdated._.updates ~= nil)
                assert.equal(nil, plugins.current._.updates)
                assert.equal(nil, plugins.pinned._.updates)
                assert.equal(nil, plugins.local_plugin._.updates)
                assert.equal(nil, plugins.not_installed._.updates)
            end
        )

        it("populates M.updated with the names that have updates", function()
            Checker.fast_check({ report = false })
            assert.same({ "outdated" }, Checker.updated)
        end)
    end)

    describe("report()", function()
        local restore_config, restore_headless, restore_util
        local info_calls

        before_each(function()
            info_calls       = {}
            restore_config   = Mocks.patch_config(
                { checker = { notify = true } }
            )
            restore_headless = Mocks.patch("lazy.core.config", {
                headless = function()
                    return false
                end,
            })
            restore_util     = Mocks.patch("lazy.util", {
                info = function(lines)
                    table.insert(info_calls, lines)
                end,
            })
        end)
        after_each(function()
            restore_config()
            restore_headless()
            restore_util()
        end)

        it("notifies once per plugin, then dedups on repeat calls", function()
            local restore_plugins = Mocks.patch("lazy.core.config", {
                plugins = {
                    p = { name = "p", _ = { updates = { from = {}, to = {} } } },
                },
            })
            MiniTest.finally(restore_plugins)

            Checker.report(true)
            Checker.report(true)

            assert.equal(1, #info_calls)
            assert.same({ "p" }, Checker.reported)
        end)

        it("does not notify when notify is false", function()
            local restore_plugins = Mocks.patch("lazy.core.config", {
                plugins = {
                    p = { name = "p", _ = { updates = { from = {}, to = {} } } },
                },
            })
            MiniTest.finally(restore_plugins)

            Checker.report(false)
            assert.equal(0, #info_calls)
        end)

        it("does not notify when there are no updates", function()
            local restore_plugins = Mocks.patch("lazy.core.config", {
                plugins = { p = { name = "p", _ = {} } },
            })
            MiniTest.finally(restore_plugins)

            Checker.report(true)
            assert.equal(0, #info_calls)
        end)
    end)

    describe("has_errors()", function()
        it("reflects Plugin.has_errors() across all plugins", function()
            local restore_config = Mocks.patch("lazy.core.config", {
                plugins = {
                    ok = { name = "ok" },
                    bad = { name = "bad" },
                },
            })
            local restore_plugin = Mocks.patch("lazy.core.plugin", {
                has_errors = function(plugin)
                    return plugin.name == "bad"
                end,
            })
            MiniTest.finally(function()
                restore_config()
                restore_plugin()
            end)

            assert(Checker.has_errors())
        end)

        it("returns false when no plugin has errors", function()
            local restore_config = Mocks.patch("lazy.core.config", {
                plugins = { ok = { name = "ok" } },
            })
            local restore_plugin = Mocks.patch("lazy.core.plugin", {
                has_errors = function()
                    return false
                end,
            })
            MiniTest.finally(function()
                restore_config()
                restore_plugin()
            end)

            assert(not Checker.has_errors())
        end)
    end)
end)
