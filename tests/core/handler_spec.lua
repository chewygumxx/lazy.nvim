local Handler = require("lazy.core.handler")

---@param name   string
---@param values string[]
---@return LazyPlugin
local function fake_plugin(name, values)
    return { name = name, dir = "/fake", fake = values, _ = {} } --[[@as LazyPlugin]]
end

-- A synthetic handler type, registered the same way real handler types are
-- (lua/lazy/core/handler/{cmd,event,ft,keys}.lua as
-- lazy.core.handler.<type>), so Handler.new()/resolve()/enable()/disable()
-- can be exercised through their real prototype-chaining and active/managed
-- bookkeeping without touching real autocmds, user commands or keymaps.
-- "fake" is deliberately not one of the closed LazyHandlerTypes, so the type
-- checker can't reconcile it the way it would keys/event/cmd/ft; that's the
-- whole point of the isolation, not a real bug.
---@diagnostic disable: missing-fields, undefined-field, assign-type-mismatch, param-type-mismatch
describe("core.handler (base)", function()
    local added, deleted

    before_each(function()
        added, deleted                           = {}, {}
        package.loaded["lazy.core.handler.fake"] = {
            _add = function(_self, value)
                table.insert(added, value)
            end,
            _del = function(_self, value)
                table.insert(deleted, value)
            end,
        }
    end)
    after_each(function()
        package.loaded["lazy.core.handler.fake"] = nil
    end)

    describe("new()", function()
        it("sets up prototype chaining to the base handler", function()
            local h = Handler.new("fake")
            assert.equal("fake", h.type)
            assert.equal(Handler, h.super)
            assert.same({}, h.active)
            assert.same({}, h.managed)
            -- inherited from the base module via the metatable chain
            assert.equal(Handler.add, h.add)
        end)
    end)

    describe("add() / del()", function()
        it(
            "calls _add() only once for a key shared by multiple plugins",
            function()
                local h       = Handler.new("fake")
                local p1      = fake_plugin("p1", {})
                local p2      = fake_plugin("p2", {})
                p1._.handlers = { fake = { X = "X" } }
                p2._.handlers = { fake = { X = "X" } }

                h:add(p1)
                h:add(p2)

                assert.same({ "X" }, added)
                assert.same({ p1 = "p1", p2 = "p2" }, h.active.X)
                assert.equal("p1", h.managed.X)
            end
        )

        it(
            "only calls _del() once the last owning plugin is removed",
            function()
                local h       = Handler.new("fake")
                local p1      = fake_plugin("p1", {})
                local p2      = fake_plugin("p2", {})
                p1._.handlers = { fake = { X = "X" } }
                p2._.handlers = { fake = { X = "X" } }
                h:add(p1)
                h:add(p2)

                h:del(p1)
                assert.same({}, deleted)
                assert(h.active.X ~= nil, "key should still be active")

                h:del(p2)
                assert.same({ "X" }, deleted)
                assert.equal(nil, h.active.X)
            end
        )

        it("del() is a no-op when the plugin was never resolved", function()
            local h = Handler.new("fake")
            h:del(fake_plugin("never-resolved", {}))
            assert.same({}, deleted)
        end)
    end)

    describe("resolve() / enable() / disable()", function()
        local restore_handlers
        before_each(function()
            restore_handlers      = Handler.handlers.fake
            Handler.handlers.fake = Handler.new("fake")
        end)
        after_each(function()
            Handler.handlers.fake = restore_handlers
        end)

        it(
            "enable() resolves plugin._.handlers and registers its values",
            function()
                local plugin = fake_plugin("p1", { "X", "Y" })

                Handler.enable(plugin)

                assert.same({ X = "X", Y = "Y" }, plugin._.handlers.fake)
                table.sort(added)
                assert.same({ "X", "Y" }, added)
            end
        )

        it("enable() is a no-op once the plugin is loaded", function()
            local plugin    = fake_plugin("p1", { "X" })
            plugin._.loaded = true

            Handler.enable(plugin)

            assert.equal(nil, plugin._.handlers)
            assert.same({}, added)
        end)

        it("disable() removes every value the plugin owns", function()
            local plugin = fake_plugin("p1", { "X" })
            Handler.enable(plugin)

            Handler.disable(plugin)

            assert.same({ "X" }, deleted)
            assert.equal(nil, Handler.handlers.fake.active.X)
        end)
    end)
end)
