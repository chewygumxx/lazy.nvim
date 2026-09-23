local Helpers    = require("helpers")
local Mocks      = require("mocks")
local PluginTask = require("lazy.manage.task.plugin")
local Task       = require("lazy.manage.task")

describe("task.plugin", function()
    before_each(function()
        Helpers.fs_rm("task_plugin")
    end)

    describe("build.skip()", function()
        it("never skips when opts.force is set", function()
            assert(
                not PluginTask.build.skip(
                    Helpers.plugin({ _ = {} }),
                    { force = true }
                )
            )
        end)

        it(
            "skips when there is nothing dirty/built and no build file",
            function()
                local plugin = Helpers.plugin({
                    dir = Helpers.path("task_plugin/nobuild"),
                    _ = { dirty = true },
                })
                assert(PluginTask.build.skip(plugin))
            end
        )

        it(
            "does not skip a dirty plugin with an explicit build field",
            function()
                local plugin = Helpers.plugin({
                    dir = Helpers.path("task_plugin/explicit"),
                    build = "echo hi",
                    _ = { dirty = true },
                })
                assert(not PluginTask.build.skip(plugin))
            end
        )

        it("does not skip a dirty plugin with a build.lua file", function()
            Helpers.fs_create({ "task_plugin/hasfile/build.lua" })
            local plugin = Helpers.plugin({
                dir = Helpers.path("task_plugin/hasfile"),
                _ = { dirty = true },
            })
            assert(not PluginTask.build.skip(plugin))
        end)

        it(
            "skips a plugin that is neither dirty nor marked for build",
            function()
                Helpers.fs_create({ "task_plugin/notdirty/build.lua" })
                local plugin = Helpers.plugin({
                    dir = Helpers.path("task_plugin/notdirty"),
                    _ = {},
                })
                assert(PluginTask.build.skip(plugin))
            end
        )
    end)

    describe("build.run()", function()
        it("does nothing when build is explicitly false", function()
            local plugin = Helpers.plugin({
                name = "p",
                dir = Helpers.path("task_plugin/falsebuild"),
                build = false,
                _ = {},
            })
            -- if run() tried to spawn anything, this would error, since
            -- there is nothing stubbed.
            local restore = Mocks.stub_spawn({})
            local task    = Task.new(plugin, "build", PluginTask.build.run, {})
            task:wait()
            restore()

            assert(not task:has_errors(), task:output())
        end)

        it("calls a function builder directly with the plugin", function()
            local called_with
            local plugin = Helpers.plugin({
                name = "p",
                dir = Helpers.path("task_plugin/fnbuild"),
                build = function(p)
                    called_with = p
                end,
                _ = {},
            })
            local task   = Task.new(plugin, "build", PluginTask.build.run, {})
            task:wait()

            assert(not task:has_errors(), task:output())
            assert.equal(plugin, called_with)
        end)

        it("loads and executes a *.lua build file", function()
            local marker = Helpers.path("task_plugin/luabuild/marker.txt")
            Helpers.fs_write(
                "task_plugin/luabuild/do_build.lua",
                ("require('lazy.util').write_file(%q, 'built')"):format(marker)
            )
            local plugin = Helpers.plugin({
                name = "p",
                dir = Helpers.path("task_plugin/luabuild"),
                build = "do_build.lua",
                _ = {},
            })
            local task   = Task.new(plugin, "build", PluginTask.build.run, {})
            task:wait()

            assert(not task:has_errors(), task:output())
            assert.equal("built", require("lazy.util").read_file(marker))
        end)

        it("runs a plain string builder through the shell", function()
            local captured
            local restore = Mocks.patch("lazy.manage.process", {
                spawn = function(cmd, opts)
                    captured = { cmd = cmd, opts = opts }
                    return {
                        code = 0,
                        signal = 0,
                        data = "",
                        wait = function() end,
                    }
                end,
            })
            local plugin  = Helpers.plugin({
                name = "p",
                dir = Helpers.path("task_plugin/shellbuild"),
                build = "make",
                _ = {},
            })
            local task    = Task.new(plugin, "build", PluginTask.build.run, {})
            task:wait()
            restore()

            assert(not task:has_errors(), task:output())
            assert(captured ~= nil, "expected the shell builder to spawn")
            assert(vim.tbl_contains(captured.opts.args, "make"))
        end)
    end)

    describe("docs.skip()", function()
        it("skips when neither local nor dirty", function()
            assert(PluginTask.docs.skip(Helpers.plugin({ _ = {} })))
        end)

        it("does not skip a local plugin", function()
            assert(
                not PluginTask.docs.skip(
                    Helpers.plugin({ _ = { is_local = true } })
                )
            )
        end)

        it("does not skip a dirty plugin", function()
            assert(
                not PluginTask.docs.skip(
                    Helpers.plugin({ _ = { dirty = true } })
                )
            )
        end)
    end)

    describe("docs.run()", function()
        it("runs helptags when a doc/ directory exists", function()
            Helpers.fs_write(
                "task_plugin/withdocs/doc/foo.txt",
                "*foo* some help\n"
            )
            local plugin = Helpers.plugin({
                name = "p",
                dir = Helpers.path("task_plugin/withdocs"),
                _ = {},
            })
            local task   = Task.new(plugin, "docs", PluginTask.docs.run, {})
            task:wait()

            assert(not task:has_errors(), task:output())
        end)

        it("does nothing when there is no doc/ directory", function()
            local plugin = Helpers.plugin({
                name = "p",
                dir = Helpers.path("task_plugin/nodocs"),
                _ = {},
            })
            local task   = Task.new(plugin, "docs", PluginTask.docs.run, {})
            task:wait()

            assert(not task:has_errors(), task:output())
        end)
    end)

    describe("exists.skip()", function()
        it("skips a non-local plugin", function()
            assert(PluginTask.exists.skip(Helpers.plugin({ _ = {} })))
        end)

        it("skips a virtual plugin", function()
            assert(
                PluginTask.exists.skip(
                    Helpers.plugin({
                        virtual = true,
                        _ = { is_local = true },
                    })
                )
            )
        end)

        it("does not skip a real local plugin", function()
            assert(
                not PluginTask.exists.skip(
                    Helpers.plugin({ _ = { is_local = true } })
                )
            )
        end)
    end)

    describe("exists.run()", function()
        it("errors when the local plugin directory is missing", function()
            local plugin = Helpers.plugin({
                name = "p",
                dir = Helpers.path("task_plugin/missing_local"),
                _ = {},
            })
            local task   = Task.new(plugin, "exists", PluginTask.exists.run, {})
            task:wait()

            assert(task:has_errors())
            assert(task:output():find("does not exist", 1, true))
        end)

        it("does not error when the local plugin directory exists", function()
            Helpers.fs_create({ "task_plugin/present_local/init.lua" })
            local plugin = Helpers.plugin({
                name = "p",
                dir = Helpers.path("task_plugin/present_local"),
                _ = {},
            })
            local task   = Task.new(plugin, "exists", PluginTask.exists.run, {})
            task:wait()

            assert(not task:has_errors(), task:output())
        end)
    end)
end)
