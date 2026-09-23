local GitTask = require("lazy.manage.task.git")
local Helpers = require("helpers")
local Mocks   = require("mocks")
local Task    = require("lazy.manage.task")

describe("task.git", function()
    before_each(function()
        Helpers.fs_rm("task_git")
    end)

    describe("log.skip()", function()
        it("skips a pinned plugin during a check", function()
            assert(
                GitTask.log.skip(
                    Helpers.plugin({ pin = true, _ = {} }),
                    { check = true }
                )
            )
        end)

        it("skips an 'updated' log when from and to are the same", function()
            local plugin = Helpers.plugin({
                _ = { updated = { from = "a", to = "a" } },
            })
            assert(GitTask.log.skip(plugin, { updated = true }))
        end)

        it(
            "does not skip an 'updated' log when from and to differ",
            function()
                Helpers.fs_create({ "task_git/r1/.git/HEAD" })
                local plugin = Helpers.plugin({
                    dir = Helpers.path("task_git/r1"),
                    _ = { updated = { from = "a", to = "b" } },
                })
                assert(not GitTask.log.skip(plugin, { updated = true }))
            end
        )

        it("skips when the plugin has no .git directory", function()
            local plugin = Helpers.plugin({
                dir = Helpers.path("task_git/missing"),
                _ = {},
            })
            assert(GitTask.log.skip(plugin, {}))
        end)

        it("does not skip a plain log when .git exists", function()
            Helpers.fs_create({ "task_git/r2/.git/HEAD" })
            local plugin = Helpers.plugin({
                dir = Helpers.path("task_git/r2"),
                _ = {},
            })
            assert(not GitTask.log.skip(plugin, {}))
        end)
    end)

    describe("clone.skip()", function()
        it("skips already-installed plugins", function()
            assert(
                GitTask.clone.skip(Helpers.plugin({ _ = { installed = true } }))
            )
        end)

        it("skips local plugins", function()
            assert(
                GitTask.clone.skip(Helpers.plugin({ _ = { is_local = true } }))
            )
        end)

        it("does not skip a not-yet-installed, non-local plugin", function()
            assert(not GitTask.clone.skip(Helpers.plugin({ _ = {} })))
        end)
    end)

    describe("branch.skip()", function()
        it("skips when not installed or local", function()
            assert(GitTask.branch.skip(Helpers.plugin({ _ = {} })))
            assert(
                GitTask.branch.skip(
                    Helpers.plugin(
                        { _ = { installed = true, is_local = true } }
                    )
                )
            )
        end)

        it("skips when the origin branch ref already exists", function()
            local restore = Mocks.patch("lazy.manage.git", {
                get_branch = function()
                    return "main"
                end,
                get_commit = function()
                    return "abc123"
                end,
            })
            local plugin  = { dir = "/x", _ = { installed = true } }
            local skip    = GitTask.branch.skip(plugin)
            restore()
            assert(skip)
        end)

        it("does not skip when the origin branch ref is missing", function()
            local restore = Mocks.patch("lazy.manage.git", {
                get_branch = function()
                    return "main"
                end,
                get_commit = function()
                    return nil
                end,
            })
            local plugin  = { dir = "/x", _ = { installed = true } }
            local skip    = GitTask.branch.skip(plugin)
            restore()
            assert(not skip)
        end)
    end)

    describe("origin.skip()", function()
        it("skips when not installed or local", function()
            assert(GitTask.origin.skip(Helpers.plugin({ _ = {} })))
        end)

        it("skips when the origin url already matches", function()
            local restore = Mocks.patch("lazy.manage.git", {
                get_origin = function()
                    return "same"
                end,
            })
            local plugin  = {
                dir = "/x",
                url = "same",
                _ = { installed = true },
            }
            local skip    = GitTask.origin.skip(plugin)
            restore()
            assert(skip)
        end)

        it("does not skip when the origin url has changed", function()
            local restore = Mocks.patch("lazy.manage.git", {
                get_origin = function()
                    return "old"
                end,
            })
            local plugin  = {
                dir = "/x",
                url = "new",
                _ = { installed = true },
            }
            local skip    = GitTask.origin.skip(plugin)
            restore()
            assert(not skip)
        end)
    end)

    describe("status.skip()", function()
        it("skips when not installed or local", function()
            assert(GitTask.status.skip(Helpers.plugin({ _ = {} })))
            assert(
                GitTask.status.skip(
                    Helpers.plugin(
                        { _ = { installed = true, is_local = true } }
                    )
                )
            )
        end)

        it("does not skip an installed, non-local plugin", function()
            assert(
                not GitTask.status.skip(
                    Helpers.plugin({ _ = { installed = true } })
                )
            )
        end)
    end)

    describe("fetch.skip()", function()
        local restore_config
        before_each(function()
            restore_config = Mocks.patch_config({ git = { cooldown = 60 } })
        end)
        after_each(function()
            restore_config()
        end)

        it("skips when not installed or local", function()
            assert(GitTask.fetch.skip(Helpers.plugin({ _ = {} })))
        end)

        it("skips within the cooldown window", function()
            local plugin = {
                _ = { installed = true, last_check = vim.uv.now() },
            }
            assert(GitTask.fetch.skip(plugin))
        end)

        it("does not skip once the cooldown has elapsed", function()
            local plugin = {
                _ = {
                    installed = true,
                    last_check = vim.uv.now() - 120 * 1000,
                },
            }
            assert(not GitTask.fetch.skip(plugin))
        end)
    end)

    describe("checkout.skip()", function()
        it("skips when not installed or local", function()
            assert(GitTask.checkout.skip(Helpers.plugin({ _ = {} })))
        end)

        it("does not skip an installed, non-local plugin", function()
            assert(
                not GitTask.checkout.skip(
                    Helpers.plugin({ _ = { installed = true } })
                )
            )
        end)
    end)

    describe("fetch.run()", function()
        it("spawns git fetch and records last_check on success", function()
            local plugin        = {
                name = "p",
                dir = Helpers.path("task_git/fetch"),
                _ = {},
            }
            local restore_spawn = Mocks.stub_spawn({
                ["git fetch --recurse-submodules --tags --force --progress"] = {
                    code = 0,
                },
            })

            local task = Task.new(plugin, "fetch", GitTask.fetch.run, {})
            task:wait()
            restore_spawn()

            assert(not task:has_errors(), task:output())
            assert(plugin._.last_check ~= nil)
        end)
    end)

    describe("checkout.run()", function()
        it(
            "short-circuits without spawning when already at the target",
            function()
                local restore_config = Mocks.patch_config({
                    git = { throttle = { enabled = false } },
                })
                local restore_git    = Mocks.patch("lazy.manage.git", {
                    info = function()
                        return { branch = "main", commit = "abc1234" }
                    end,
                    get_target = function()
                        return { branch = "main", commit = "abc1234" }
                    end,
                })
                -- if checkout.run tried to spawn, this would error because
                -- there is no stubbed response, catching a regression.
                local restore_spawn = Mocks.stub_spawn({})

                local plugin = {
                    name = "p",
                    dir = Helpers.path("task_git/checkout"),
                    _ = {},
                }
                local task   = Task.new(
                    plugin,
                    "checkout",
                    GitTask.checkout.run,
                    {}
                )
                task:wait()

                restore_config()
                restore_git()
                restore_spawn()

                assert(not task:has_errors(), task:output())
                assert.same(
                    { from = "abc1234", to = "abc1234" },
                    plugin._.updated
                )
            end
        )
    end)
end)
