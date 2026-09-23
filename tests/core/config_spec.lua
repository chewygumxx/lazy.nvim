local Config = require("lazy.core.config")

-- Config.setup() is a real integration/bootstrap function: it mutates
-- vim.opt.rtp, vim.go.packpath, registers autocmds, and requires other
-- modules that hook into it. It already runs exactly once for this entire
-- process (see tests/minit.lua), and everything else in the suite reads
-- the resulting Config.options. Calling it again here would corrupt that
-- shared state for every test that runs afterwards, so these specs only
-- cover the parts of the module that are actually safe to exercise in
-- isolation: the static defaults and the two small pure-ish functions.
describe("core.config", function()
    describe("defaults", function()
        -- These identify this specific fork (see CLAUDE.md: this repo is
        -- chewygumxx/lazy.nvim, not upstream folke/lazy.nvim). A rebase or
        -- merge from upstream is the most likely way to silently clobber
        -- them, so pin them down explicitly.
        it(
            "points at this fork's repo, not upstream folke/lazy.nvim",
            function()
                assert.equal("chewygumxx/lazy.nvim", Config.defaults[1])
                assert.equal(
                    "https://github.com/chewygumxx/lazy.nvim",
                    Config.defaults.url
                )
                assert.equal("chewygumxx", Config.defaults.branch)
            end
        )

        it("keeps the fork's dev.patterns and colorscheme defaults", function()
            assert(
                vim.tbl_contains(Config.defaults.dev.patterns, "chewygumxx")
            )
            assert(
                vim.tbl_contains(
                    Config.defaults.install.colorscheme,
                    "middlenight_blue"
                )
            )
        end)

        it("setup()'s table.insert into options.install.colorscheme "
            .. "also mutates defaults (vim.tbl_deep_extend aliases "
            .. "sub-tables the override doesn't touch, it does not "
            .. "deep-copy them)", function()
            -- This pins down current, somewhat surprising behavior
            -- rather than asserting the "obviously correct" one: a
            -- second Config.setup() call reusing these defaults would
            -- append "habamax" again, accumulating duplicates.
            assert(
                vim.tbl_contains(
                    Config.defaults.install.colorscheme,
                    "habamax"
                )
            )
        end)
    end)

    it("version is a dotted numeric string", function()
        assert(Config.version:match("^%d+%.%d+%.%d+$"), Config.version)
    end)

    describe("hererocks()", function()
        local saved
        before_each(function()
            saved = Config.options.rocks.hererocks
        end)
        after_each(function()
            Config.options.rocks.hererocks = saved
        end)

        it("returns the cached value without recomputing", function()
            Config.options.rocks.hererocks = true
            assert.equal(true, Config.hererocks())

            Config.options.rocks.hererocks = false
            assert.equal(false, Config.hererocks())
        end)

        it("computes and memoizes a boolean when unset", function()
            Config.options.rocks.hererocks = nil
            local ret                      = Config.hererocks()
            assert(type(ret) == "boolean")
            assert.equal(ret, Config.options.rocks.hererocks)
        end)
    end)

    describe("headless()", function()
        local saved
        before_each(function()
            saved = Config.suspended
        end)
        after_each(function()
            Config.suspended = saved
        end)

        it(
            "is headless when not suspended (no UI attached in tests)",
            function()
                Config.suspended = false
                assert.equal(true, Config.headless())
            end
        )

        it("is not headless while suspended", function()
            Config.suspended = true
            assert.equal(false, Config.headless())
        end)
    end)
end)
