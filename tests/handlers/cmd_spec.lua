local Cmd = require("lazy.core.handler.cmd")

describe("handler.cmd", function()
    describe("parse()", function()
        it("turns a bare string into a named LazyCmd", function()
            local cmd = Cmd.parse("Foo")
            assert.equal("Foo", cmd.name)
            assert.equal("Foo", cmd.id)
            assert.equal(nil, cmd.callback)
        end)

        it(
            "turns a spec table into a LazyCmd, keeping the callback",
            function()
                local cb  = function() end
                local cmd = Cmd.parse({ "Foo", cb, desc = "d", nargs = "*" })
                assert.equal("Foo", cmd.name)
                assert.equal("Foo", cmd.id)
                assert.equal(cb, cmd.callback)
                assert.equal("d", cmd.desc)
                assert.equal("*", cmd.nargs)
            end
        )
    end)

    it("resolve() keys parsed commands by id", function()
        local values = Cmd.resolve({ "Foo", { "Bar", desc = "d" } })
        assert.equal("Foo", values.Foo.name)
        assert.equal("Bar", values.Bar.name)
        assert.equal("d", values.Bar.desc)
    end)

    it(
        "opts() strips name/id/callback and numeric keys, keeps the rest",
        function()
            local cmd  = Cmd.parse({
                "Foo",
                function() end,
                desc = "d",
                bang = true,
            })
            local opts = Cmd.opts(cmd)
            assert.same({ desc = "d", bang = true }, opts)
        end
    )
end)
