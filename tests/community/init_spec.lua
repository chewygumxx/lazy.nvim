local Community = require("lazy.community")

describe("community", function()
    describe("get_url()", function()
        it("resolves a known rock name to its url", function()
            assert.equal(
                "NStefan002/15puzzle.nvim",
                Community.get_url("15puzzle.nvim")
            )
        end)

        it("returns nil for an unknown rock name", function()
            assert.equal(nil, Community.get_url("does-not-exist.nvim"))
        end)

        it("memoizes the mapping across repeated calls", function()
            local first  = Community.get_url("15puzzle.nvim")
            local second = Community.get_url("15puzzle.nvim")
            assert.equal(first, second)
        end)
    end)

    describe("get_spec()", function()
        it("returns the curated spec for a known plugin", function()
            assert.same(
                { "nvim-lua/plenary.nvim", lazy = true },
                Community.get_spec("plenary.nvim")
            )
        end)

        it("returns nil for a plugin with no curated spec", function()
            assert.equal(nil, Community.get_spec("does-not-exist.nvim"))
        end)
    end)
end)
