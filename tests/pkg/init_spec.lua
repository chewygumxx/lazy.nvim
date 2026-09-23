local Helpers = require("helpers")
local Mocks   = require("mocks")
local Pkg     = require("lazy.pkg")

describe("pkg", function()
    local restore_config

    before_each(function()
        Helpers.fs_rm("pkg_init")
        -- force a reload from disk on the next Pkg.cache access, since it's
        -- a module-level singleton memoized behind a __index metamethod
        Pkg.cache = nil
    end)
    after_each(function()
        if restore_config then
            restore_config()
            restore_config = nil
        end
        Pkg.cache = nil
    end)

    describe("cache loading", function()
        it("is empty and dirty when there is no cache file on disk", function()
            restore_config = Mocks.patch_config({
                pkg = { cache = Helpers.path("pkg_init/missing.lua") },
            })

            assert.same({}, Pkg.cache)
            assert.equal(true, Pkg.dirty)
        end)

        it("loads matching-version cached pkgs, wrapping each spec under "
            .. "{ name, specs = <original spec> }", function()
            local path     = Helpers.fs_write(
                "pkg_init/valid.lua",
                [[return {
                        version = 12,
                        pkgs = {
                            {
                                name = "foo",
                                dir = "/foo",
                                source = "lazy",
                                file = "lazy.lua",
                                spec = { "some/plugin" },
                            },
                        },
                    }]]
            )
            restore_config = Mocks.patch_config({
                pkg = { cache = path },
            })

            assert.equal(1, #Pkg.cache)
            assert.equal(false, Pkg.dirty)

            local pkg = Pkg.get("/foo")
            assert(pkg)
            assert.equal("foo", pkg.name)
            assert.same({ "foo", specs = { "some/plugin" } }, pkg.spec)
            assert.equal(nil, Pkg.get("/does-not-exist"))
        end)

        it("discards a cache file from a different VERSION", function()
            local path     = Helpers.fs_write(
                "pkg_init/stale.lua",
                "return { version = 1, pkgs = { { name = 'x' } } }"
            )
            restore_config = Mocks.patch_config({
                pkg = { cache = path },
            })

            assert.same({}, Pkg.cache)
            assert.equal(true, Pkg.dirty)
        end)
    end)

    describe("update()", function()
        it("writes installed plugins' pkgs to disk and the reloaded "
            .. "cache reflects them", function()
            local cache_path = Helpers.path("pkg_init/update.lua")
            local dir        = Helpers.path("pkg_init/plugin")
            Helpers.fs_write(
                "pkg_init/plugin/lazy.lua",
                "return { 'x/y' }"
            )

            restore_config        = Mocks.patch_config({
                pkg = { cache = cache_path, sources = { "lazy" } },
            })
            local restore_plugins = Mocks.patch("lazy.core.config", {
                plugins = {
                    installed = Helpers.plugin({
                        name = "installed",
                        dir = dir,
                        _ = { installed = true },
                    }),
                    skipped = Helpers.plugin({
                        name = "skipped",
                        dir = Helpers.path("pkg_init/notinstalled"),
                        _ = { installed = false },
                    }),
                },
            })

            Pkg.update()
            restore_plugins()

            assert(vim.uv.fs_stat(cache_path) ~= nil)

            -- force a reload from the file Pkg.update() just wrote
            Pkg.cache = nil
            assert.equal(1, #Pkg.cache)
            local pkg = Pkg.get(dir)
            assert(pkg)
            assert.equal("installed", pkg.name)
            assert.equal("lazy", pkg.source)
        end)
    end)
end)
