local Helpers = require("helpers")
local Lazy    = require("lazy.pkg.lazy")

describe("pkg.lazy", function()
    before_each(function()
        Helpers.fs_rm("pkg_lazy")
    end)

    it("returns nil when there is no lazy.lua file", function()
        local plugin = Helpers.plugin({ dir = Helpers.path("pkg_lazy/none") })
        assert.equal(nil, Lazy.get(plugin))
    end)

    it("wraps an existing lazy.lua file's contents in a function", function()
        local dir = Helpers.path("pkg_lazy/present")
        Helpers.fs_write(
            "pkg_lazy/present/lazy.lua",
            "return { 'some/plugin' }"
        )
        local plugin = Helpers.plugin({ dir = dir })

        -- pkg.lazy's M.get() is annotated `---@return LazyPkg?`, but it
        -- actually returns the shape of LazyPkgSpec (file/source/code),
        -- which is what pkg/init.lua's M.update() expects from every
        -- source's get(). The annotation itself looks like a copy/paste
        -- slip, not the runtime value.
        local pkg = Lazy.get(plugin) --[[@as LazyPkgSpec]]
        assert(pkg ~= nil)
        assert.equal("lazy", pkg.source)
        assert.equal("lazy.lua", pkg.file)
        assert.equal(
            "function()\nreturn { 'some/plugin' }\nend",
            pkg.code
        )

        -- the wrapped code should actually evaluate to the original spec
        local fn = loadstring("return " .. pkg.code)
        assert(fn)
        assert.same({ "some/plugin" }, fn()())
    end)
end)
