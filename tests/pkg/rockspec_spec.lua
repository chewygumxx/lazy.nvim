local Helpers  = require("helpers")
local Mocks    = require("mocks")
local Rockspec = require("lazy.pkg.rockspec")

describe("pkg.rockspec", function()
    before_each(function()
        Helpers.fs_rm("pkg_rockspec")
    end)

    -- these fixtures deliberately only set the `build` field is_simple_build
    -- actually reads, not the rest of RockSpec's required fields
    ---@diagnostic disable: missing-fields
    describe("is_simple_build()", function()
        it("is simple when there is no build field", function()
            assert(Rockspec.is_simple_build({}))
        end)

        it("is simple for build.type == 'none'", function()
            assert(Rockspec.is_simple_build({ build = { type = "none" } }))
        end)

        it("is simple for build.type == 'builtin' with no modules", function()
            assert(
                Rockspec.is_simple_build({ build = { type = "builtin" } })
            )
        end)

        it("is not simple for build.type == 'builtin' with modules", function()
            assert(
                not Rockspec.is_simple_build({
                    build = { type = "builtin", modules = { "x" } },
                })
            )
        end)

        it("is not simple for any other build.type", function()
            assert(
                not Rockspec.is_simple_build({ build = { type = "make" } })
            )
        end)
    end)
    ---@diagnostic enable: missing-fields

    describe("parse() / rockspec()", function()
        it("evaluates a rockspec file's assignments into a table", function()
            local file   = Helpers.fs_write(
                "pkg_rockspec/valid/foo-scm-1.rockspec",
                'package = "foo"\nversion = "scm-1"\ndependencies = {"lua"}'
            )
            local parsed = Rockspec.rockspec(file)
            assert(parsed)
            assert.equal("foo", parsed.package)
            assert.equal("scm-1", parsed.version)
            assert.same({ "lua" }, parsed.dependencies)
        end)

        it("returns nil for a missing file", function()
            assert.equal(
                nil,
                Rockspec.rockspec(Helpers.path("pkg_rockspec/missing.rockspec"))
            )
        end)

        it("returns nil for a file with invalid Lua", function()
            local file = Helpers.fs_write(
                "pkg_rockspec/broken/foo-scm-1.rockspec",
                "this is not valid lua ("
            )
            assert.equal(nil, Rockspec.rockspec(file))
        end)
    end)

    describe("find_rockspec()", function()
        it(
            "finds a scm/git/dev -1.rockspec file in the plugin dir",
            function()
                local dir = Helpers.path("pkg_rockspec/found")
                Helpers.fs_write(
                    "pkg_rockspec/found/plugin-scm-1.rockspec",
                    ""
                )
                assert.equal(
                    dir .. "/plugin-scm-1.rockspec",
                    Rockspec.find_rockspec(Helpers.plugin({ dir = dir }))
                )
            end
        )

        it(
            "does not match a versioned rockspec that isn't scm/git/dev",
            function()
                local dir = Helpers.path("pkg_rockspec/versioned")
                Helpers.fs_write(
                    "pkg_rockspec/versioned/plugin-1.0-1.rockspec",
                    ""
                )
                assert.equal(
                    nil,
                    Rockspec.find_rockspec(Helpers.plugin({ dir = dir }))
                )
            end
        )

        it("returns nil when the dir has no rockspec file", function()
            local dir = Helpers.path("pkg_rockspec/empty")
            Helpers.fs_create({ "pkg_rockspec/empty/init.lua" })
            assert.equal(
                nil,
                Rockspec.find_rockspec(Helpers.plugin({ dir = dir }))
            )
        end)
    end)

    describe("get()", function()
        it("short-circuits on a known community spec", function()
            local restore = Mocks.patch("lazy.community", {
                get_spec = function(name)
                    return name == "known" and { "known/plugin" } or nil
                end,
            })
            local plugin  = Helpers.plugin({ name = "known" })
            local pkg     = Rockspec.get(plugin)
            restore()

            assert(pkg)
            assert.equal("community", pkg.file)
            assert.equal("lazy", pkg.source)
            assert.same({ "known/plugin" }, pkg.spec)
        end)

        it("returns nil when there is no rockspec file", function()
            local plugin = Helpers.plugin({
                name = "none",
                dir = Helpers.path("pkg_rockspec/get_none"),
            })
            assert.equal(nil, Rockspec.get(plugin))
        end)

        it(
            "returns nil for a simple build with only skipped deps and a " .. "lua/ dir",
            function()
                Helpers.fs_create({ "pkg_rockspec/get_simple/lua/init.lua" })
                Helpers.fs_write(
                    "pkg_rockspec/get_simple/plugin-scm-1.rockspec",
                    'package = "plugin"\ndependencies = {"lua"}'
                )
                local plugin = Helpers.plugin({
                    name = "plugin",
                    dir = Helpers.path("pkg_rockspec/get_simple"),
                })
                assert.equal(nil, Rockspec.get(plugin))
            end
        )

        it("requires a rockspec build when there is no lua/ dir", function()
            Helpers.fs_write(
                "pkg_rockspec/get_nolua/plugin-scm-1.rockspec",
                'package = "plugin"\ndependencies = {"lua"}'
            )
            local plugin = Helpers.plugin({
                name = "plugin",
                dir = Helpers.path("pkg_rockspec/get_nolua"),
            })

            local pkg = Rockspec.get(plugin)
            assert(pkg ~= nil)
            assert.same({
                "plugin",
                build = "rockspec",
                lazy = false,
            }, pkg.spec)
        end)

        it("requires a rockspec build for a non-simple build.type even "
            .. "with a lua/ dir", function()
            Helpers.fs_create({ "pkg_rockspec/get_complex/lua/init.lua" })
            Helpers.fs_write(
                "pkg_rockspec/get_complex/plugin-scm-1.rockspec",
                'package = "plugin"\nbuild = { type = "make" }'
            )
            local plugin = Helpers.plugin({
                name = "plugin",
                dir = Helpers.path("pkg_rockspec/get_complex"),
            })

            local pkg = Rockspec.get(plugin)
            assert(pkg ~= nil)
            assert.equal("rockspec", pkg.spec.build)
            assert.equal(nil, pkg.spec.lazy)
        end)

        it("maps a community-known dependency to its own spec entry "
            .. "instead of a rockspec build", function()
            local restore = Mocks.patch("lazy.community", {
                get_spec = function()
                    return nil
                end,
                get_url = function(name)
                    return name == "fake-community-dep"
                        and "https://github.com/nvim-lua/plenary.nvim"
                        or nil
                end,
            })
            Helpers.fs_create({ "pkg_rockspec/get_maps/lua/init.lua" })
            Helpers.fs_write(
                "pkg_rockspec/get_maps/plugin-scm-1.rockspec",
                'package = "plugin"\ndependencies = {"fake-community-dep"}'
            )
            local plugin = Helpers.plugin({
                name = "plugin",
                dir = Helpers.path("pkg_rockspec/get_maps"),
            })

            local pkg = Rockspec.get(plugin)
            restore()

            assert(pkg ~= nil)
            assert.same({
                "plugin",
                specs = {
                    { "https://github.com/nvim-lua/plenary.nvim" },
                },
                build = false,
            }, pkg.spec)
        end)
    end)
end)
