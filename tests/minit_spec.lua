local Minit = require("lazy.minit")

describe("minit", function()
    describe("extend()", function()
        it("concatenates list-style spec fields, defaults first", function()
            local merged = Minit.extend(
                { spec = { "a/one", "a/two" } },
                { spec = { "b/three" } }
            )
            assert.same({ "a/one", "a/two", "b/three" }, merged.spec)
        end)

        it("wraps a non-list spec table as a single spec entry", function()
            local merged = Minit.extend(
                { spec = { dir = "/defaults-plugin" } },
                { spec = { dir = "/opts-plugin" } }
            )
            assert.same(
                { { dir = "/defaults-plugin" }, { dir = "/opts-plugin" } },
                merged.spec
            )
        end)

        it("treats a missing spec on either side as empty", function()
            assert.same(
                { "only" },
                Minit.extend({}, { spec = { "only" } }).spec
            )
            assert.same(
                { "only" },
                Minit.extend({ spec = { "only" } }, {}).spec
            )
            assert.same({}, Minit.extend({}, {}).spec)
        end)

        it("deep-merges other config fields with opts winning", function()
            local merged = Minit.extend(
                { local_spec = true, install = { colorscheme = { "a" } } },
                { local_spec = false }
            )
            assert.equal(false, merged.local_spec)
            assert.same({ "a" }, merged.install.colorscheme)
        end)
    end)
end)
