local Helpers  = require("helpers")
local Packspec = require("lazy.pkg.packspec")

-- pkg.packspec's M.get() is annotated `---@return LazyPkg?`, but like
-- pkg.lazy it actually returns the LazyPkgSpec shape (file/source/spec).
---@param plugin LazyPlugin
---@return LazyPkgSpec?
local function get(plugin)
    return Packspec.get(plugin) --[[@as LazyPkgSpec]]
end

describe("pkg.packspec", function()
    before_each(function()
        Helpers.fs_rm("pkg_packspec")
    end)

    it("returns nil when there is no pkg.json file", function()
        local plugin = Helpers.plugin({
            dir = Helpers.path("pkg_packspec/none"),
        })
        assert.equal(nil, Packspec.get(plugin))
    end)

    it("returns nil when pkg.json is not valid JSON", function()
        local dir = Helpers.path("pkg_packspec/malformed")
        Helpers.fs_write("pkg_packspec/malformed/pkg.json", "{not json")
        local plugin = Helpers.plugin({ dir = dir })
        assert.equal(nil, Packspec.get(plugin))
    end)

    it("adds `.git` to bare github dependency urls", function()
        local dir = Helpers.path("pkg_packspec/deps")
        Helpers.fs_write(
            "pkg_packspec/deps/pkg.json",
            vim.json.encode({
                dependencies = { ["https://github.com/foo/bar"] = "1.0" },
            })
        )
        local plugin = Helpers.plugin({ dir = dir })

        local pkg = get(plugin)
        assert(pkg ~= nil)
        assert.same(
            { { url = "https://github.com/foo/bar.git", version = "1.0" } },
            pkg.spec
        )
    end)

    it("leaves non-github dependency urls untouched", function()
        local dir = Helpers.path("pkg_packspec/nongithub")
        Helpers.fs_write(
            "pkg_packspec/nongithub/pkg.json",
            vim.json.encode({
                dependencies = { ["https://gitlab.com/foo/bar"] = "*" },
            })
        )
        local plugin = Helpers.plugin({ dir = dir })

        local pkg = get(plugin)
        assert(pkg)
        assert.same(
            { { url = "https://gitlab.com/foo/bar", version = "*" } },
            pkg.spec
        )
    end)

    it("fills in url/dir on pkg.lazy from the plugin when unset, and "
        .. "currently appends it twice (pkg.lazy is inserted once via "
        .. "the `p` local and a second time via the raw `pkg.lazy` "
        .. "check right after -- both branches share the same table)", function()
        local dir = Helpers.path("pkg_packspec/lazyfield")
        Helpers.fs_write(
            "pkg_packspec/lazyfield/pkg.json",
            vim.json.encode({ lazy = { cmd = "Foo" } })
        )
        local plugin = Helpers.plugin({
            dir = dir,
            url = "https://example.com/foo.git",
        })

        local pkg = get(plugin)
        assert(pkg)
        local specs = pkg.spec --[[@as LazyPluginSpec[] ]]
        assert.equal(2, #specs)
        for _, entry in ipairs(specs) do
            assert.equal("Foo", entry.cmd)
            assert.equal("https://example.com/foo.git", entry.url)
            assert.equal(dir, entry.dir)
        end
    end)

    it("does not overwrite an explicit url/dir on pkg.lazy", function()
        local dir = Helpers.path("pkg_packspec/lazyexplicit")
        Helpers.fs_write(
            "pkg_packspec/lazyexplicit/pkg.json",
            vim.json.encode({
                lazy = { url = "https://explicit.example.com/x.git" },
            })
        )
        local plugin = Helpers.plugin({
            dir = dir,
            url = "https://example.com/foo.git",
        })

        local pkg = get(plugin)
        assert(pkg)
        assert.equal(
            "https://explicit.example.com/x.git",
            pkg.spec[1].url
        )
    end)
end)
