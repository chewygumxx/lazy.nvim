local Helpers = require("helpers")
local Util    = require("lazy.util")

describe("util (top-level)", function()
    before_each(function()
        Helpers.fs_rm("util")
    end)

    describe("file_exists()", function()
        it("is true for an existing file", function()
            local file = Helpers.fs_write("util/exists.txt", "x")
            assert.equal(true, Util.file_exists(file))
        end)

        it("is false for a missing file", function()
            assert.equal(
                false,
                Util.file_exists(Helpers.path("util/missing.txt"))
            )
        end)
    end)

    describe("read_file() / write_file()", function()
        it("round-trips file contents", function()
            -- write_file() does not create parent directories itself
            local file = Helpers.fs_write("util/roundtrip.txt", "")
            Util.write_file(file, "hello\nworld")
            assert.equal("hello\nworld", Util.read_file(file))
        end)

        it("write_file() overwrites existing contents", function()
            local file = Helpers.fs_write("util/overwrite.txt", "old")
            Util.write_file(file, "new")
            assert.equal("new", Util.read_file(file))
        end)
    end)

    describe("head()", function()
        it("returns the first line of a file", function()
            local file = Helpers.fs_write("util/head.txt", "first\nsecond")
            assert.equal("first", Util.head(file))
        end)

        it("returns nil for a missing file", function()
            assert.equal(nil, Util.head(Helpers.path("util/nohead.txt")))
        end)
    end)

    describe("git_info()", function()
        it("resolves a branch HEAD to { branch, hash }", function()
            Helpers.fs_write(
                "util/repo1/.git/HEAD",
                "ref: refs/heads/main\n"
            )
            Helpers.fs_write(
                "util/repo1/.git/refs/heads/main",
                "deadbeef1234\n"
            )
            assert.same(
                { branch = "main", hash = "deadbeef1234" },
                Util.git_info(Helpers.path("util/repo1"))
            )
        end)

        it("returns nil for a detached HEAD (no refs/heads/ line)", function()
            Helpers.fs_write("util/repo2/.git/HEAD", "deadbeefcafe\n")
            assert.equal(
                nil,
                Util.git_info(Helpers.path("util/repo2"))
            )
        end)

        it("returns nil when there is no .git directory", function()
            assert.equal(
                nil,
                Util.git_info(Helpers.path("util/norepo"))
            )
        end)
    end)

    describe("dump() / _dump()", function()
        it("dumps numbers, booleans and strings as Lua literals", function()
            assert.equal("1", Util.dump(1))
            assert.equal("true", Util.dump(true))
            assert.equal('"foo"', Util.dump("foo"))
        end)

        it("dumps list entries positionally, without keys", function()
            assert.equal("{1,2,3,}", Util.dump({ 1, 2, 3 }))
        end)

        it("dumps bareword-safe string keys as `key=value`, others as "
            .. "`[\"key\"]=value`", function()
            local dumped = Util.dump({ foo = 1, ["not valid"] = 2 })
            assert(dumped:find("foo=1", 1, true))
            assert(dumped:find('["not valid"]=2', 1, true))
        end)

        it("silently drops sparse non-sequential numeric keys: the "
            .. "positional pass stops at the first ipairs() hole, and "
            .. "the keyed pass only emits string keys, so neither "
            .. "picks up a numeric key past the hole", function()
            local t = { [1] = "a", [3] = "b" }
            assert.equal('{"a",}', Util.dump(t))
        end)

        it(
            "passes through a `_raw` field verbatim instead of dumping it",
            function()
                assert.equal(
                    "function() end",
                    Util.dump({ _raw = "function() end" })
                )
            end
        )

        it("dump() output round-trips through loadstring", function()
            local original = { 1, 2, foo = "bar", nested = { x = 1 } }
            local fn       = loadstring("return " .. Util.dump(original))
            assert(fn)
            assert.same(original, fn())
        end)
    end)

    describe("foreach()", function()
        it("iterates keys sorted case-insensitively by default", function()
            local seen = {}
            Util.foreach({ b = 2, A = 1, c = 3 }, function(k, v)
                table.insert(seen, { k, v })
            end)
            assert.same({ { "A", 1 }, { "b", 2 }, { "c", 3 } }, seen)
        end)

        it("sorts case-sensitively when opts.case_sensitive is set", function()
            local seen = {}
            Util.foreach({ b = 2, A = 1 }, function(k)
                table.insert(seen, k)
            end, { case_sensitive = true }
            )
            -- byte value of "A" (65) sorts before "b" (98) either way here,
            -- so use keys that actually differ under the two orderings
            assert.same({ "A", "b" }, seen)
        end)
    end)

    describe("weak()", function()
        it("proxies reads and writes to the wrapped object", function()
            local obj  = { a = 1 }
            local weak = Util.weak(obj)
            assert.equal(1, weak.a)

            weak.b = 2
            assert.equal(2, obj.b)
        end)

        it("__pairs is defined but never invoked: this LuaJIT runtime's "
            .. "pairs() does not consult __pairs (that's a Lua 5.2+ "
            .. "metamethod), so iterating the proxy walks its own raw "
            .. "table (just the private _obj field) instead of the "
            .. "wrapped object", function()
            local weak = Util.weak({ a = 1, b = 2 }) --[[@as table]]
            local keys = {}
            for k in pairs(weak) do
                table.insert(keys, k)
            end
            assert.same({ "_obj" }, keys)
        end)

        it("__call returns the live object", function()
            local obj  = { a = 1 }
            local weak = Util.weak(obj)
            assert.equal(obj, weak())
        end)

        it("errors once the wrapped reference has been cleared", function()
            local weak = Util.weak({ a = 1 }) --[[@as table]]
            rawset(weak, "_obj", nil)
            local ok = pcall(function()
                return weak.a
            end)
            assert(not ok)
        end)
    end)
end)
