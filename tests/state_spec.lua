local Helpers = require("helpers")
local Mocks   = require("mocks")
local State   = require("lazy.state")

describe("state", function()
    local restore_config
    after_each(function()
        if restore_config then
            restore_config()
            restore_config = nil
        end
    end)

    -- State's `data` is a module-level local with no exposed reset hook
    -- (unlike e.g. Lock._loaded/Lock.lock), and read() only overwrites it
    -- from disk on success -- a failed decode silently keeps whatever was
    -- already in memory. This test therefore only holds as written the
    -- first time anything in the process reads State; it must stay first
    -- in this file, before the other tests below give `data` a value.
    it("read() falls back to defaults when there is no state file", function()
        restore_config = Mocks.patch_config({
            state = Helpers.path("state/missing.json"),
        })
        State.read()
        assert.equal(0, State.checker.last_check)
    end)

    it("read() merges decoded file content over the defaults", function()
        local path     = Helpers.fs_write(
            "state/existing.json",
            vim.json.encode({ checker = { last_check = 999 } })
        )
        restore_config = Mocks.patch_config({ state = path })

        State.read()

        assert.equal(999, State.checker.last_check)
    end)

    it("write() persists the current in-memory state to disk", function()
        local path     = Helpers.path("state/roundtrip.json")
        restore_config = Mocks.patch_config({ state = path })

        State.read()
        State.checker.last_check = 1234
        State.write()

        local written = vim.json.decode(require("lazy.util").read_file(path))
        assert.equal(1234, written.checker.last_check)
    end)

    it("__setindex is a typo for __newindex, so it is never actually "
        .. "invoked by Lua: top-level assignment on the module (as "
        .. "opposed to mutating an existing nested table returned by "
        .. "__index, which is how the only real caller uses it, see "
        .. "manage/checker.lua) lands as a plain field on the module "
        .. "table instead of going through the read/write-backed data", function()
        restore_config = Mocks.patch_config({
            state = Helpers.path("state/setindex.json"),
        })
        State.read()

        ---@diagnostic disable-next-line: inject-field
        State.some_new_top_level_field = "value"

        -- landed directly on the module table, bypassing State's own
        -- read/write-backed data
        assert.equal("value", rawget(State, "some_new_top_level_field"))

        State.write()
        local written = vim.json.decode(
            require("lazy.util").read_file(
                Helpers.path("state/setindex.json")
            )
        )
        assert.equal(nil, written.some_new_top_level_field)
    end)
end)
