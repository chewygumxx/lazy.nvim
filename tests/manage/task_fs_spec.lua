local Fs      = require("lazy.manage.task.fs")
local Helpers = require("helpers")
local Mocks   = require("mocks")
local Task    = require("lazy.manage.task")

describe("task.fs", function()
    local restore_config

    before_each(function()
        Helpers.fs_rm("task_fs")
        restore_config = Mocks.patch_config({
            root = Helpers.path("task_fs/root"),
            rocks = { root = Helpers.path("task_fs/rocks") },
        })
    end)
    after_each(function()
        restore_config()
    end)

    describe("clean.skip()", function()
        it("skips local plugins", function()
            assert(Fs.clean.skip(Helpers.plugin({ _ = { is_local = true } })))
        end)

        it("does not skip non-local plugins", function()
            assert(not Fs.clean.skip(Helpers.plugin({ _ = {} })))
        end)
    end)

    describe("clean.run()", function()
        it("removes the plugin directory and marks it uninstalled", function()
            local dir = Helpers.path("task_fs/root/myplugin")
            Helpers.fs_create({ "task_fs/root/myplugin/init.lua" })

            local plugin = Helpers.plugin({ name = "myplugin", dir = dir })
            local task   = Task.new(plugin, "clean", Fs.clean.run, {})
            task:wait()

            assert(not task:has_errors(), task:output())
            assert.equal(nil, vim.uv.fs_stat(dir))
            assert.equal(false, plugin._.installed)
        end)

        it("also removes an existing rocks directory", function()
            local dir       = Helpers.path("task_fs/root/myplugin")
            local rock_root = Helpers.path("task_fs/rocks/myplugin")
            Helpers.fs_create({
                "task_fs/root/myplugin/init.lua",
                "task_fs/rocks/myplugin/lib/foo.lua",
            })

            local plugin = Helpers.plugin({ name = "myplugin", dir = dir })
            local task   = Task.new(plugin, "clean", Fs.clean.run, {})
            task:wait()

            assert(not task:has_errors(), task:output())
            assert.equal(nil, vim.uv.fs_stat(dir))
            assert.equal(nil, vim.uv.fs_stat(rock_root))
        end)

        it(
            "with rocks_only=true removes only the rocks dir, leaving the plugin installed",
            function()
                local dir       = Helpers.path("task_fs/root/myplugin")
                local rock_root = Helpers.path("task_fs/rocks/myplugin")
                Helpers.fs_create({
                    "task_fs/root/myplugin/init.lua",
                    "task_fs/rocks/myplugin/lib/foo.lua",
                })

                local plugin = Helpers.plugin({
                    name = "myplugin",
                    dir = dir,
                    _ = { installed = true },
                })
                local task   = Task.new(
                    plugin,
                    "clean",
                    Fs.clean.run,
                    { rocks_only = true }
                )
                task:wait()

                assert(not task:has_errors(), task:output())
                assert(vim.uv.fs_stat(dir) ~= nil, "plugin dir should remain")
                assert.equal(nil, vim.uv.fs_stat(rock_root))
                assert.equal(true, plugin._.installed)
            end
        )

        it(
            "refuses to remove a directory outside the configured root",
            function()
                local outside = Helpers.path("task_fs/outside/myplugin")
                Helpers.fs_create({ "task_fs/outside/myplugin/init.lua" })

                local plugin = Helpers.plugin(
                    { name = "myplugin", dir = outside }
                )
                local task   = Task.new(plugin, "clean", Fs.clean.run, {})
                task:wait()

                assert(
                    task:has_errors(),
                    "expected the packpath assertion to fail"
                )
                assert(
                    vim.uv.fs_stat(outside) ~= nil,
                    "dir should be untouched"
                )
            end
        )
    end)
end)
