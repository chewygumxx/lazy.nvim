-- Wall-clock budget guards for hot paths. These are not micro-benchmarks;
-- they exist to catch an accidental O(n^2) (or worse) regression sneaking
-- in during refactor. Budgets are set generously above the measured
-- baseline so they don't flake on slower CI hardware.
local MiniTest = require("mini.test")
local Plugin   = require("lazy.core.plugin")
local Semver   = require("lazy.manage.semver")
local Text     = require("lazy.view.text")

---@param fn fun()
---@return number ms
local function time_ms(fn)
    local start = vim.uv.hrtime()
    fn()
    return (vim.uv.hrtime() - start) / 1e6
end

describe("perf", function()
    it(
        "Fragments:add() stays roughly linear for many distinct plugins",
        function()
            local spec      = Plugin.Spec.new(nil, { pkg = false })
            local Fragments = spec.meta.fragments
            local n         = 2000

            local elapsed = time_ms(function()
                for i = 1, n do
                    Fragments:add({ ("owner/plugin-%d"):format(i) })
                end
            end)

            assert.is_true(elapsed < 5000)
        end
    )

    it("Semver.last() stays fast when sorting many versions", function()
        local versions = {}
        for i = 1, 5000 do
            versions[i] = ("%d.%d.%d"):format(i % 50, i % 20, i % 10)
        end

        local elapsed = time_ms(function()
            local parsed = vim.tbl_map(Semver.version, versions)
            Semver.last(parsed)
        end)

        assert.is_true(elapsed < 2000)
    end)

    it("Text:append() stays fast for many lines", function()
        local text = Text.new()
        local n    = 5000

        local elapsed = time_ms(function()
            for i = 1, n do
                text:append(("line %d"):format(i))
                text:nl()
            end
        end)

        assert.is_true(elapsed < 3000)
        assert.equal(n + 1, text:row())
    end)

    it(
        "full spec resolution stays fast for a long dependency chain",
        function()
            -- This mirrors the real startup hot path: Spec.new() parses
            -- every declared plugin into fragments, then meta:resolve()
            -- rebuilds each plugin and loops fix_disabled()+fix_optional()
            -- until no more plugins are dropped. A chain (rather than
            -- independent plugins) also exercises the dependency walk in
            -- fix_cond()/_rebuild(), which is where an accidental O(n^2)
            -- during refactor is most likely to hide.
            local n     = 1000
            local specs = {}
            for i = 1, n do
                specs[i] = {
                    ("owner/plugin-%d"):format(i),
                    dependencies = i > 1
                        and { ("owner/plugin-%d"):format(i - 1) }
                        or nil,
                }
            end

            local spec
            local elapsed = time_ms(function()
                spec = Plugin.Spec.new(specs, { pkg = false })
                spec.meta:resolve()
            end)

            assert.is_true(elapsed < 5000)
            assert.equal(n, vim.tbl_count(spec.plugins))
        end
    )
end)
