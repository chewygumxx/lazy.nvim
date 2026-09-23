local Helpers  = require("helpers")
local Lock     = require("lazy.manage.lock")
local Mocks    = require("mocks")
local MiniTest = require("mini.test")
local Util     = require("lazy.util")

describe("lock", function()
    before_each(function()
        Helpers.fs_rm("lock")
        -- M._loaded / M.lock are module-level singleton state; reset them
        -- so each test starts from a clean slate regardless of run order.
        Lock._loaded = false
        Lock.lock    = {}
    end)

    it("load() is a no-op when there is no lockfile on disk", function()
        local restore = Mocks.patch_config({
            lockfile = Helpers.path("lock/missing-lock.json"),
        })
        MiniTest.finally(restore)

        Lock.load()
        assert.same({}, Lock.lock)
    end)

    it("load() decodes an existing lockfile", function()
        local path    = Helpers.fs_write(
            "lock/lazy-lock.json",
            [[{"foo": {"branch": "main", "commit": "abc123"}}]]
        )
        local restore = Mocks.patch_config({ lockfile = path })
        MiniTest.finally(restore)

        Lock.load()
        assert.same({ foo = { branch = "main", commit = "abc123" } }, Lock.lock)
    end)

    it("load() only reads from disk once per process", function()
        local path    = Helpers.fs_write(
            "lock/once.json",
            [[{"foo": {"branch": "main", "commit": "abc123"}}]]
        )
        local restore = Mocks.patch_config({ lockfile = path })
        MiniTest.finally(restore)

        Lock.load()
        Util.write_file(path, "{}")
        Lock.load()
        assert.same({ foo = { branch = "main", commit = "abc123" } }, Lock.lock)
    end)

    it("get() looks up a plugin's entry, loading lazily", function()
        local path    = Helpers.fs_write(
            "lock/get.json",
            [[{"foo": {"branch": "main", "commit": "abc123"}}]]
        )
        local restore = Mocks.patch_config({ lockfile = path })
        MiniTest.finally(restore)

        assert.same(
            { branch = "main", commit = "abc123" },
            Lock.get(Helpers.plugin({ name = "foo" }))
        )
        assert.equal(nil, Lock.get(Helpers.plugin({ name = "bar" })))
    end)

    it(
        "update() writes only installed, non-local plugins, sorted by name",
        function()
            local path           = Helpers.path("lock/update.json")
            local restore_config = Mocks.patch_config({ lockfile = path })
            local restore_spec   = Mocks.patch("lazy.core.config", {
                spec = { disabled = {}, ignore_installed = {} },
                plugins = {
                    zeta = {
                        name = "zeta",
                        dir = "/zeta",
                        _ = { installed = true },
                    },
                    alpha = {
                        name = "alpha",
                        dir = "/alpha",
                        _ = { installed = true },
                    },
                    skipped_local = {
                        name = "skipped_local",
                        dir = "/local",
                        _ = { installed = true, is_local = true },
                    },
                    skipped_uninstalled = {
                        name = "skipped_uninstalled",
                        dir = "/gone",
                        _ = { installed = false },
                    },
                },
            })
            local restore_git    = Mocks.patch("lazy.manage.git", {
                info = function(dir)
                    return { branch = "main", commit = "commit-" .. dir }
                end,
            })
            MiniTest.finally(function()
                restore_config()
                restore_spec()
                restore_git()
            end)

            Lock.update()

            local written = vim.json.decode(Util.read_file(path))
            assert.same({
                alpha = { branch = "main", commit = "commit-/alpha" },
                zeta = { branch = "main", commit = "commit-/zeta" },
            }, written)
        end
    )

    it(
        "update() preserves disabled/ignore_installed entries and drops other stale ones",
        function()
            local path           = Helpers.path("lock/prune.json")
            local restore_config = Mocks.patch_config({ lockfile = path })
            local restore_spec   = Mocks.patch("lazy.core.config", {
                spec = {
                    disabled = { kept_disabled = true },
                    ignore_installed = { kept_ignored = true },
                },
                plugins = {},
            })
            MiniTest.finally(function()
                restore_config()
                restore_spec()
            end)

            Lock.lock    = {
                kept_disabled = { branch = "main", commit = "a" },
                kept_ignored = { branch = "main", commit = "b" },
                stale = { branch = "main", commit = "c" },
            }
            Lock._loaded = true

            Lock.update()

            local written = vim.json.decode(Util.read_file(path))
            assert.same({
                kept_disabled = { branch = "main", commit = "a" },
                kept_ignored = { branch = "main", commit = "b" },
            }, written)
        end
    )
end)
